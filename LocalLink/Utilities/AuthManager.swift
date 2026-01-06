import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthManager: ObservableObject {

    enum UserRole: String {
        case customer
        case business
    }

    @Published private(set) var role: UserRole?

    @AppStorage("userRole") private var storedRole: String?

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    init() {
        // Restore role instantly on launch
        if let storedRole,
           let role = UserRole(rawValue: storedRole) {
            self.role = role
        }

        // Listen for auth changes (future-proofing)
        authHandle = Auth.auth().addStateDidChangeListener { _, _ in }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - Role Management (APP SESSION)

    func setRole(_ role: UserRole) {
        self.role = role
        self.storedRole = role.rawValue

        // Fire-and-forget backend sync
        syncRoleToFirestore(role)
    }

    func clearRole() {
        self.role = nil
        self.storedRole = nil
    }

    // MARK: - Firebase Logout (explicit)

    func logout() {
        clearRole()
        do {
            try Auth.auth().signOut()
        } catch {
            print("Logout failed:", error)
        }
    }

    // MARK: - Firestore Sync (non-blocking)

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

