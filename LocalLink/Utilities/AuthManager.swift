import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {

    @Published var isReady = false
    @Published var userRole: UserRole?

    private let db = Firestore.firestore()

    init() {
        if let user = Auth.auth().currentUser {
            loadRole(for: user.uid)
        } else {
            Auth.auth().signInAnonymously { result, _ in
                if let uid = result?.user.uid {
                    self.loadRole(for: uid)
                }
            }
        }
    }

    func setRole(_ role: UserRole) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .setData(["role": role.rawValue], merge: true)

        self.userRole = role
    }

    func clearRole() {
        self.userRole = nil
    }

    private func loadRole(for uid: String) {
        db.collection("users")
            .document(uid)
            .getDocument { snapshot, _ in
                let roleString = snapshot?.data()?["role"] as? String
                self.userRole = roleString.flatMap(UserRole.init(rawValue:))
                self.isReady = true
            }
    }
}
