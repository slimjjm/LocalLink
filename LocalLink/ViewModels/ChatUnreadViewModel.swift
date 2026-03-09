import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class ChatUnreadViewModel: ObservableObject {

    @Published var totalUnread: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(role: String) {

        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("bookings")
            .whereField(role == "customer" ? "customerId" : "businessId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in

                guard let documents = snapshot?.documents else { return }

                var total = 0

                for doc in documents {
                    if role == "customer" {
                        total += doc.data()["unreadForCustomer"] as? Int ?? 0
                    } else {
                        total += doc.data()["unreadForBusiness"] as? Int ?? 0
                    }
                }

                self?.totalUnread = total
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
