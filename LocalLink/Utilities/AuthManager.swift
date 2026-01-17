import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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

    // Lazy Firestore (safe at launch)
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
        if Auth.auth().currentUser == nil && allowAnonymousAuth {
            signInAnonymously()
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

    // MARK: - Login
    func login(
        email: String,
        password: String,
        completion: @escaping (Bool) -> Void
    ) {
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

    // MARK: - Register
    func signUp(
        email: String,
        password: String,
        completion: @escaping (Bool) -> Void
    ) {
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

    // MARK: - Role
    func setRole(_ role: UserRole) {
        self.role = role
        storedRole = role.rawValue
        syncRoleToFirestore(role)
    }

    func clearRole() {
        role = nil
        storedRole = nil
    }

    // MARK: - Logout (NO NAVIGATION HERE)
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
            .setData(
                ["role": role.rawValue],
                merge: true
            )
    }
}

