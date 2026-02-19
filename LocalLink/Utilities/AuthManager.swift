import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn

@MainActor
final class AuthManager: ObservableObject {

    enum UserRole: String {
        case customer
        case business
    }

    // MARK: - Published State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var role: UserRole?

    @AppStorage("userRole") private var storedRole: String?
    @AppStorage("allowAnonymousAuth") private var allowAnonymousAuth = true

    private lazy var db = Firestore.firestore()

    // MARK: - Init
    init() {
        if let storedRole,
           let role = UserRole(rawValue: storedRole) {
            self.role = role
        }

        DispatchQueue.main.async {
            self.startSessionIfNeeded()
        }
    }

    // MARK: - Session bootstrap
    private func startSessionIfNeeded() {
        if Auth.auth().currentUser == nil && allowAnonymousAuth == true {
            // Guest session only created when user taps guest
        }
    }

    // MARK: - Anonymous
    func signInAnonymously() {
        Auth.auth().signInAnonymously { result, error in
            if let error {
                print("❌ Anonymous sign-in failed:", error.localizedDescription)
            } else {
                print("✅ Anonymous session:", result?.user.uid ?? "")
            }
        }
    }

    // MARK: - Flow control
    func requireFullLogin() {
        allowAnonymousAuth = false
    }

    func allowAnonymousAgain() {
        allowAnonymousAuth = true
        if Auth.auth().currentUser == nil {
            signInAnonymously()
        }
    }

    // MARK: - Email Login
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                } else {
                    self.allowAnonymousAuth = true
                    completion(true)
                }
            }
        }
    }

    // MARK: - Email Register
    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        if let user = Auth.auth().currentUser, user.isAnonymous {
            let credential = EmailAuthProvider.credential(
                withEmail: email,
                password: password
            )

            user.link(with: credential) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        completion(false)
                        return
                    }

                    result?.user.sendEmailVerification()
                    self.allowAnonymousAuth = true
                    completion(true)
                }
            }
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }

                result?.user.sendEmailVerification()
                self.allowAnonymousAuth = true
                completion(true)
            }
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller")
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ Missing Firebase clientID")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                print("❌ Google sign-in error:", error.localizedDescription)
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ Missing Google auth data")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error = error {
                    print("❌ Firebase Google login failed:", error.localizedDescription)
                } else {
                    print("✅ Google login success")
                    self.allowAnonymousAuth = true
                }
            }
        }
    }

    // MARK: - Role
    func setRole(_ role: UserRole) {
        self.role = role
        storedRole = role.rawValue

        NotificationCenter.default.post(name: .didSelectRole, object: nil)
        syncRoleToFirestore(role)
    }

    func clearRole() {
        role = nil
        storedRole = nil
    }

    // MARK: - Logout
    func logout() {
        clearRole()

        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ Logout failed:", error.localizedDescription)
        }

        if allowAnonymousAuth {
            signInAnonymously()
        }
    }

    // MARK: - Firestore sync
    private func syncRoleToFirestore(_ role: UserRole) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .setData(["role": role.rawValue], merge: true)
    }
}
