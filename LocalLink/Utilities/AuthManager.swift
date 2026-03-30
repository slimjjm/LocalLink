import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import AuthenticationServices

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
                
                if let user, !user.isAnonymous {
                    self.isAuthenticated = true
                } else {
                    self.isAuthenticated = false
                }
                
                guard let user else {
                    self.role = nil
                    self.isRoleLoading = false
                    self.showEmailVerification = false
                    return
                }
                
                if user.isAnonymous {
                    self.role = nil
                    self.isRoleLoading = false
                    self.showEmailVerification = false
                    return
                }
                
                self.isRoleLoading = true
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
            
            if let error = error {
                print("❌ Email check error:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            let exists = !(methods ?? []).isEmpty
            
            DispatchQueue.main.async {
                completion(exists)
            }
        }
    }
    // MARK: - Role Loading
    
    func loadUserRole(uid: String) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error {
                    print("❌ Failed to load role:", error.localizedDescription)
                    self.role = .customer
                    self.storedRole = UserRole.customer.rawValue
                    return
                }
                
                if let roleString = snapshot?.data()?["role"] as? String,
                   let parsedRole = UserRole(rawValue: roleString) {
                    self.role = parsedRole
                    self.storedRole = parsedRole.rawValue
                    print("✅ Role loaded:", parsedRole.rawValue)
                } else {
                    print("⚠️ No role found, defaulting to customer")
                    self.role = .customer
                    self.storedRole = UserRole.customer.rawValue
                }
            }
        }
    }
    
    func loadRoleFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else {
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
                
                guard let data = snapshot?.data(),
                      let roleString = data["role"] as? String,
                      let parsedRole = UserRole(rawValue: roleString) else {
                    self.role = nil
                    self.storedRole = nil
                    return
                }
                
                self.role = parsedRole
                self.storedRole = parsedRole.rawValue
            }
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
                    self.errorMessage = error.localizedDescription
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
        
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedEmail.isEmpty, !password.isEmpty else {
            isLoading = false
            errorMessage = "Please enter email and password"
            completion(false)
            return
        }
        
        if let user = Auth.auth().currentUser, !user.isAnonymous {
            do {
                try Auth.auth().signOut()
                print("✅ Cleared existing session for:", user.uid)
            } catch {
                print("❌ Failed to sign out:", error.localizedDescription)
            }
        }
        
        Auth.auth().signIn(withEmail: cleanedEmail, password: password) { [weak self] result, error in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    let nsError = error as NSError
                    self.errorMessage = self.messageForAuthError(nsError)
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
                completion(true)
            }
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
                    
                    self.ensureUserDocument(user: user)
                    user.sendEmailVerification { sendError in
                        if let sendError {
                            print("⚠️ Email verification send failed:", sendError.localizedDescription)
                        }
                    }
                    
                    self.allowAnonymousAuth = false
                    self.showEmailVerification = true
                    self.isAuthenticated = true
                    self.loadUserRole(uid: user.uid)
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
                
                self.ensureUserDocument(user: user)
                user.sendEmailVerification { sendError in
                    if let sendError {
                        print("⚠️ Email verification send failed:", sendError.localizedDescription)
                    }
                }
                
                self.allowAnonymousAuth = false
                self.showEmailVerification = true
                self.isAuthenticated = true
                self.loadUserRole(uid: user.uid)
                completion(true)
            }
        }
    }
    
    // Convenience alias if any older view still calls signup(...)
    func signup(email: String, password: String, completion: @escaping (Bool) -> Void) {
        signUp(email: email, password: password, completion: completion)
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        showEmailVerification = false
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isLoading = false
            errorMessage = "Unable to access the login window."
            completion(false)
            return
        }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            isLoading = false
            errorMessage = "Missing Firebase client ID."
            completion(false)
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self else { return }
            
            if let error {
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
                            
                            Auth.auth().signIn(with: updatedCredential) { [weak self] result, error in
                                guard let self else { return }
                                
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    
                                    if let error {
                                        self.errorMessage = error.localizedDescription
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
                                    completion(true)
                                }
                            }
                            
                            return
                        }
                        
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
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
                    self.errorMessage = error.localizedDescription
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
                completion(true)
            }
        }
    }
    
    // MARK: - Firestore User
    
    func ensureUserDocument(user: User) {
        let ref = db.collection("users").document(user.uid)
        
        ref.getDocument { snapshot, error in
            if let error {
                print("❌ Error checking user document:", error.localizedDescription)
                return
            }
            
            if snapshot?.exists == false {
                ref.setData([
                    "email": user.email ?? "",
                    "role": "customer",
                    "createdAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error {
                        print("❌ Error creating user document:", error.localizedDescription)
                    } else {
                        print("✅ Created Firestore user profile")
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
    
    func clearEmailVerificationPrompt() {
        showEmailVerification = false
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
        
        isAuthenticated = false
        role = nil
        isRoleLoading = false
        showEmailVerification = false
        errorMessage = nil
        storedRole = nil
    }
    
    // MARK: - Firestore Sync
    
    private func syncRoleToFirestore(_ role: UserRole) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(uid)
            .setData(["role": role.rawValue], merge: true)
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
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please try again later."
        default:
            return isSignup ? "Could not create account" : "Login failed. Please try again."
        }
    }
}
