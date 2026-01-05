import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {

    enum FlowState {
        case loading
        case unauthenticated
        case selectingRole
        case onboardingBusiness
        case business
        case customer
    }

    @Published var flowState: FlowState = .loading

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            guard let user else {
                self.flowState = .unauthenticated
                return
            }

            self.loadRole(for: user.uid)
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - Public API

    func beginBusinessOnboarding() {
        flowState = .onboardingBusiness
    }

    func completeBusinessOnboarding() {
        setRole(.business)
    }

    func setRole(_ role: UserRole) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .setData(["role": role.rawValue], merge: true)

        flowState = role == .business ? .business : .customer
    }

    /// ✅ FIXED: this is a REAL logout
    func clearRole() {
        do {
            try Auth.auth().signOut()
            flowState = .unauthenticated
        } catch {
            print("Logout failed:", error)
        }
    }

    // MARK: - Private

    private func loadRole(for uid: String) {
        flowState = .loading

        db.collection("users")
            .document(uid)
            .getDocument { snapshot, _ in
                let role = snapshot?.data()?["role"] as? String

                DispatchQueue.main.async {
                    if let role, let parsed = UserRole(rawValue: role) {
                        self.flowState = parsed == .business ? .business : .customer
                    } else {
                        self.flowState = .selectingRole
                    }
                }
            }
    }
}

