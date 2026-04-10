import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import FirebaseMessaging

@MainActor
final class AuthManager: ObservableObject {
    
    enum UserRole: String {
        case customer
        case business
    }
    
    // MARK: - Published State
    
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var role: UserRole?
    @Published var isRoleLoading: Bool = true
    @Published var showEmailVerification = false
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Persistence
    
    @AppStorage("userRole") private var storedRole: String?
    @AppStorage("allowAnonymousAuth") private var allowAnonymousAuth = true
    
    private let emailForSignInKey = "emailForSignIn"
    
    // MARK: - Private
    
    private lazy var db = Firestore.firestore()
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Init
    
    init() {
        if let storedRole,
           let parsedRole = UserRole(rawValue: storedRole) {
            self.role = parsedRole
        }
        
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            
            Task { @MainActor in
                self.errorMessage = nil
                
                guard let user else {
                    self.isAuthenticated = false
                    self.role = nil
                    self.isRoleLoading = false
                    self.showEmailVerification = false
                    return
                }
                
                if user.isAnonymous {
                    self.isAuthenticated = true   // 🔥 KEY CHANGE
                    self.isRoleLoading = false
                    return
                }
                
                self.isAuthenticated = true
                self.isRoleLoading = true
                
                if !user.isEmailVerified,
                   self.isPasswordProviderUser(user) {
                    self.showEmailVerification = true
                } else {
                    self.showEmailVerification = false
                }
                
                self.loadRoleFromFirestore()
            }
        }
        
        if Auth.auth().currentUser == nil {
            isRoleLoading = false
        }
    }
    
    deinit {
        if let authListenerHandle {
            Auth.auth().removeStateDidChangeListener(authListenerHandle)
        }
    }
    
    // MARK: - Email Existence Check
    
    func checkIfUserExists(email: String, completion: @escaping (Bool) -> Void) {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedEmail.isEmpty else {
            completion(false)
            return
        }
        
        Auth.auth().fetchSignInMethods(forEmail: cleanedEmail) { methods, error in
            DispatchQueue.main.async {
                if let error {
                    print("❌ Email check error:", error.localizedDescription)
                    completion(false)
                    return
                }
                
                let exists = !(methods ?? []).isEmpty
                completion(exists)
            }
        }
    }
    
    // MARK: - Role Loading
    
    func loadUserRole(uid: String, completion: (() -> Void)? = nil) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            
            DispatchQueue.main.async {
                if let roleString = snapshot?.data()?["role"] as? String,
                   let parsedRole = UserRole(rawValue: roleString) {
                    self.role = parsedRole
                    self.storedRole = parsedRole.rawValue
                } else {
                    self.role = .customer
                    self.storedRole = UserRole.customer.rawValue
                }
                
                self.isRoleLoading = false
                completion?()
            }
        }
    }
    
    func loadRoleFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else {
            role = nil
            storedRole = nil
            isRoleLoading = false
            return
        }
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            
            DispatchQueue.main.async {
                defer { self.isRoleLoading = false }
                
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                if let roleString = snapshot?.data()?["role"] as? String,
                   let parsedRole = UserRole(rawValue: roleString) {
                    self.role = parsedRole
                    self.storedRole = parsedRole.rawValue
                } else {
                    self.role = .customer
                    self.storedRole = UserRole.customer.rawValue
                    
                    if let uid = Auth.auth().currentUser?.uid {
                        self.db.collection("users")
                            .document(uid)
                            .setData(["role": UserRole.customer.rawValue], merge: true)
                    }
                }
            }
        }
    }
    // MARK: - Google Sign In

    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        
        isLoading = true
        errorMessage = nil
        showEmailVerification = false
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isLoading = false
            errorMessage = "Missing Firebase client ID."
            completion(false)
            return
        }
        
        guard let rootVC = topViewController() else {
            isLoading = false
            errorMessage = "Unable to access the login window."
            completion(false)
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Missing Google account details."
                    completion(false)
                }
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            self.authenticateWithFirebase(credential: credential, completion: completion)
        }
    }
    // MARK: - Anonymous
    
    func signInAnonymously(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signInAnonymously { [weak self] _, error in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    self.errorMessage = self.messageForAuthError(error as NSError)
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }
    }
    
    func requireFullLogin() {
        allowAnonymousAuth = false
    }
    
    func allowAnonymousAgain() {
        allowAnonymousAuth = true
        
        if Auth.auth().currentUser == nil {
            signInAnonymously { _ in }
        }
    }
    
    // MARK: - Email Login
    
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        errorMessage = nil
        isLoading = true
        showEmailVerification = false
        
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedEmail.isEmpty, !password.isEmpty else {
            isLoading = false
            errorMessage = "Please enter email and password"
            completion(false)
            return
        }
        
        let signInBlock = {
            Auth.auth().signIn(withEmail: cleanedEmail, password: password) { [weak self] result, error in
                guard let self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error {
                        self.errorMessage = self.messageForAuthError(error as NSError)
                        print("🔥 Login error:", error.localizedDescription)
                        completion(false)
                        return
                    }
                    
                    guard let user = result?.user else {
                        self.errorMessage = "Login failed."
                        completion(false)
                        return
                    }
                    
                    self.ensureUserDocument(user: user)
                    self.isAuthenticated = true
                    self.loadUserRole(uid: user.uid)
                    
                    // 🔥 CRITICAL FIX
                    MessagingDelegateHandler.shared.flushPendingTokenIfNeeded()
                    
                    if self.isPasswordProviderUser(user), !user.isEmailVerified {
                        self.showEmailVerification = true
                    }
                    
                    completion(true)
                }
            }
        }
        
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            currentUser.delete { error in
                DispatchQueue.main.async {
                    if let error {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        completion(false)
                        return
                    }
                    
                    signInBlock()
                }
            }
        } else {
            signInBlock()
        }
    }
    
    // MARK: - Email Sign Up
    
    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        showEmailVerification = false
        
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedEmail.isEmpty, !password.isEmpty else {
            isLoading = false
            errorMessage = "Please enter email and password"
            completion(false)
            return
        }
        
        guard let bundleID = Bundle.main.bundleIdentifier else {
            isLoading = false
            errorMessage = "Missing app bundle identifier."
            completion(false)
            return
        }
        
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(bundleID)
        actionCodeSettings.url = URL(string: "https://locallink-995a5.web.app/open")!
        
        if let user = Auth.auth().currentUser, user.isAnonymous {
            let credential = EmailAuthProvider.credential(
                withEmail: cleanedEmail,
                password: password
            )
            
            user.link(with: credential) { [weak self] result, error in
                guard let self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error {
                        let nsError = error as NSError
                        self.errorMessage = self.messageForAuthError(nsError, isSignup: true)
                        print("🔥 Anonymous link signup error:", error.localizedDescription)
                        completion(false)
                        return
                    }
                    
                    guard let user = result?.user else {
                        self.errorMessage = "Could not create account"
                        completion(false)
                        return
                    }
                    
                    self.finishSignup(user: user, actionCodeSettings: actionCodeSettings)
                    completion(true)
                }
            }
            
            return
        }
        
        Auth.auth().createUser(withEmail: cleanedEmail, password: password) { [weak self] result, error in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    let nsError = error as NSError
                    self.errorMessage = self.messageForAuthError(nsError, isSignup: true)
                    print("🔥 Signup error:", error.localizedDescription)
                    completion(false)
                    return
                }
                
                guard let user = result?.user else {
                    self.errorMessage = "Could not create account"
                    completion(false)
                    return
                }
                
                self.finishSignup(user: user, actionCodeSettings: actionCodeSettings)
                completion(true)
            }
        }
    }
    
    func signup(email: String, password: String, completion: @escaping (Bool) -> Void) {
        signUp(email: email, password: password, completion: completion)
    }
    
    private func finishSignup(user: User, actionCodeSettings: ActionCodeSettings) {
        ensureUserDocument(user: user)
        
        user.sendEmailVerification(with: actionCodeSettings) { error in
            if let error {
                print("⚠️ Email verification send failed:", error.localizedDescription)
            } else {
                print("✅ Verification email sent")
            }
        }
        
        allowAnonymousAuth = false
        showEmailVerification = true
        isAuthenticated = true
        loadUserRole(uid: user.uid)
    }
    
    // MARK: - Email Verification
    
    func resendVerificationEmail(completion: @escaping (Bool) -> Void) {
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No signed-in user."
            completion(false)
            return
        }
        
        guard let bundleID = Bundle.main.bundleIdentifier else {
            errorMessage = "Missing app bundle identifier."
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(bundleID)
        actionCodeSettings.url = URL(string: "https://locallink-995a5.web.app/open")
        
        user.sendEmailVerification(with: actionCodeSettings) { [weak self] error in
            
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }
    }
    
    func refreshEmailVerificationStatus(completion: ((Bool) -> Void)? = nil) {
        
        guard let user = Auth.auth().currentUser else {
            showEmailVerification = false
            completion?(false)
            return
        }
        
        user.reload { [weak self] error in
            
            guard let self else { return }
            
            DispatchQueue.main.async {
                
                if let error {
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                    return
                }
                
                if user.isEmailVerified || !self.isPasswordProviderUser(user) {
                    self.showEmailVerification = false
                } else {
                    self.showEmailVerification = true
                }
                
                completion?(user.isEmailVerified)
            }
        }
    }
    
    func clearEmailVerificationPrompt() {
        showEmailVerification = false
    }
    
    //
    // MARK: - Magic Link (Send)

    func sendMagicLink(email: String, completion: @escaping (Bool) -> Void) {
        
        isLoading = true
        errorMessage = nil
        
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedEmail.isEmpty else {
            isLoading = false
            errorMessage = "Enter your email"
            completion(false)
            return
        }
        
        guard let bundleID = Bundle.main.bundleIdentifier else {
            isLoading = false
            errorMessage = "Missing app bundle identifier."
            completion(false)
            return
        }
        
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://locallink-995a5.web.app/open")!
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(bundleID)
        
        Auth.auth().sendSignInLink(toEmail: cleanedEmail, actionCodeSettings: actionCodeSettings) { [weak self] error in
            
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    self.errorMessage = self.messageForAuthError(error as NSError)
                    completion(false)
                    return
                }
                
                UserDefaults.standard.set(cleanedEmail, forKey: self.emailForSignInKey)
                completion(true)
            }
        }
    }


    // MARK: - Magic Link (Complete)

    func completeMagicLinkSignIn(from url: URL, completion: @escaping (Bool) -> Void) {
        
        let rawLink = url.absoluteString
        let link = rawLink.removingPercentEncoding ?? rawLink
        
        print("🔥 Incoming magic link:", link)
        
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            print("❌ Invalid email link")
            completion(false)
            return
        }
        
        guard let email = UserDefaults.standard.string(forKey: emailForSignInKey),
              !email.isEmpty else {
            errorMessage = "Missing email. Request a new link."
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        func finishSignIn(user: User, completion: @escaping (Bool) -> Void) {
            
            print("✅ Signed in:", user.uid)
            
            UserDefaults.standard.removeObject(forKey: self.emailForSignInKey)
            
            self.ensureUserDocument(user: user)
            self.allowAnonymousAuth = false
            self.showEmailVerification = false
            
            self.loadUserRole(uid: user.uid) { [weak self] in
                
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    
                    // 🔥 CRITICAL FIX
                    MessagingDelegateHandler.shared.flushPendingTokenIfNeeded()
                    
                    NotificationCenter.default.post(
                        name: .didSelectRole,
                        object: nil
                    )
                    
                    completion(true)
                }
            }
        }
        
        func performSignIn() {
            
            Auth.auth().signIn(withEmail: email, link: link) { [weak self] result, error in
                
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ Sign-in error:", error.localizedDescription)
                        self.errorMessage = self.messageForAuthError(error as NSError)
                        completion(false)
                        return
                    }
                    
                    guard let user = result?.user else {
                        self.errorMessage = "Magic link sign-in failed."
                        completion(false)
                        return
                    }
                    
                    finishSignIn(user: user) { success in
                        completion(success)
                    }
                }
            }
        }
        
        if let currentUser = Auth.auth().currentUser,
           currentUser.isAnonymous {
            
            print("🔥 Linking anonymous user → email account")
            
            let credential = EmailAuthProvider.credential(
                withEmail: email,
                link: link
            )
            
            currentUser.link(with: credential) { [weak self] result, error in
                
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    
                    if let error = error {
                        print("⚠️ Link failed, falling back:", error.localizedDescription)
                        performSignIn()
                        return
                    }
                    
                    guard let user = result?.user else {
                        self.errorMessage = "Account upgrade failed."
                        self.isLoading = false
                        completion(false)
                        return
                    }
                    
                    self.isLoading = false
                    
                    finishSignIn(user: user) { success in
                        completion(success)
                    }
                }
            }
            
        } else {
            performSignIn()
        }
    }
    
        // MARK: - Apple Sign In
    
    func signInWithApple(idTokenString: String, rawNonce: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        showEmailVerification = false
        
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: rawNonce
        )
        
        authenticateWithFirebase(credential: credential, completion: completion)
    }
    
    // MARK: - Core Social Auth
    
    private func authenticateWithFirebase(credential: AuthCredential, completion: @escaping (Bool) -> Void) {
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            currentUser.link(with: credential) { [weak self] result, error in
                guard let self else { return }
                
                DispatchQueue.main.async {
                    if let error {
                        let nsError = error as NSError
                        
                        if nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue,
                           let updatedCredential = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                            
                            self.signInDirectly(with: updatedCredential, completion: completion)
                            return
                        }
                        
                        if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue ||
                            nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
                            self.isLoading = false
                            self.errorMessage = self.messageForAuthError(nsError)
                            completion(false)
                            return
                        }
                        
                        self.isLoading = false
                        self.errorMessage = self.messageForAuthError(nsError)
                        completion(false)
                        return
                    }
                    
                    guard let user = result?.user else {
                        self.isLoading = false
                        self.errorMessage = "Authentication failed."
                        completion(false)
                        return
                    }
                    
                    self.ensureUserDocument(user: user)
                    self.isLoading = false
                    self.allowAnonymousAuth = false
                    self.showEmailVerification = false
                    self.isAuthenticated = true
                    self.loadUserRole(uid: user.uid)
                    completion(true)
                }
            }
        } else {
            signInDirectly(with: credential, completion: completion)
        }
    }
    
private func signInDirectly(with credential: AuthCredential, completion: @escaping (Bool) -> Void) {
    Auth.auth().signIn(with: credential) { [weak self] result, error in
        guard let self else { return }
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let error {
                self.errorMessage = self.messageForAuthError(error as NSError)
                completion(false)
                return
            }
            
            guard let user = result?.user else {
                self.errorMessage = "Authentication failed."
                completion(false)
                return
            }
            
            self.ensureUserDocument(user: user)
            self.allowAnonymousAuth = false
            self.showEmailVerification = false
            self.isAuthenticated = true
            self.loadUserRole(uid: user.uid)
            
            // 🔥 CRITICAL FIX
            MessagingDelegateHandler.shared.flushPendingTokenIfNeeded()
            
            completion(true)
        }
    }
}
    
    // MARK: - Firestore User
    
    func ensureUserDocument(user: User) {
        
        let ref = db.collection("users").document(user.uid)
        
        ref.getDocument { [weak self] snapshot, error in
            guard let self else { return }
            
            if let error {
                print("❌ Error checking user document:", error.localizedDescription)
                return
            }
            
            // 🔥 PRIORITY NAME SOURCES
            let displayName = user.displayName
            
            let emailName = user.email?
                .components(separatedBy: "@")
                .first
            
            let finalName =
                displayName ??
                emailName ??
                "Customer"
            
            let baseData: [String: Any] = [
                "email": user.email ?? "",
                "name": finalName, // ✅ THIS IS THE FIX
                "role": "customer",
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            if snapshot?.exists == false {
                
                ref.setData(baseData) { error in
                    if let error {
                        print("❌ Error creating user document:", error.localizedDescription)
                    } else {
                        print("✅ Created Firestore user profile WITH NAME")
                    }
                }
                
            } else {
                
                ref.setData([
                    "email": user.email ?? "",
                    "name": finalName // ✅ ALSO UPDATE EXISTING USERS
                ], merge: true) { error in
                    if let error {
                        print("❌ Error syncing user data:", error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // MARK: - Role Actions
    
    func setRole(_ role: UserRole) {
        self.role = role
        storedRole = role.rawValue
        
        if role == .business {
            allowAnonymousAuth = false
        }
        
        NotificationCenter.default.post(name: .didSelectRole, object: nil)
        syncRoleToFirestore(role)
    }
    
    func clearRole() {
        role = nil
        storedRole = nil
    }
    
    // MARK: - Logout
    
    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ Logout failed:", error.localizedDescription)
        }
        
        // 🔥 Reset local state
        isAuthenticated = false
        role = nil
        isRoleLoading = false
        showEmailVerification = false
        errorMessage = nil
        storedRole = nil
        
        // 🚨 THIS IS THE MISSING PIECE
        NotificationCenter.default.post(name: .didLogout, object: nil)
    }
   
    // MARK: - Firestore Sync
    
    private func syncRoleToFirestore(_ role: UserRole) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(uid)
            .setData(["role": role.rawValue], merge: true)
    }
    
    // MARK: - Helpers
    
    private func isPasswordProviderUser(_ user: User) -> Bool {
        user.providerData.contains { $0.providerID == EmailAuthProviderID }
    }
    
    private func topViewController(
        base: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        
        return base
    }
    
    // MARK: - Error Mapping
    
    private func messageForAuthError(_ error: NSError, isSignup: Bool = false) -> String {
        switch error.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password"
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found for this email"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email address"
        case AuthErrorCode.invalidCredential.rawValue:
            return "Invalid email or password"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return isSignup ? "Account already exists. Please log in." : "Email already in use"
        case AuthErrorCode.weakPassword.rawValue:
            return "Password must be at least 6 characters"
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Check your connection and try again."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please try again later."
        case AuthErrorCode.userDisabled.rawValue:
            return "This account has been disabled."
        case AuthErrorCode.credentialAlreadyInUse.rawValue:
            return "That sign-in method is already linked to another account."
        case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
            return "An account already exists with a different sign-in method."
        case AuthErrorCode.invalidActionCode.rawValue:
            return "This link is invalid or has expired."
        case AuthErrorCode.expiredActionCode.rawValue:
            return "This link has expired. Please request a new one."
        default:
            return error.localizedDescription.isEmpty ? "Something went wrong. Please try again." : error.localizedDescription
        }
    }
}
extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}

