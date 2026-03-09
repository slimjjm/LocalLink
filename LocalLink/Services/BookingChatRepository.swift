import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class BookingChatRepository {

    private let db = Firestore.firestore()

    func sendMessage(
        bookingId: String,
        businessId: String,
        customerId: String,
        text: String,
        senderRole: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        guard let senderId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: 0)))
            return
        }

        let bookingRef = db.collection("bookings").document(bookingId)
        let messagesRef = bookingRef.collection("messages").document()

        let batch = db.batch()

        // 1️⃣ Create message
        let messageData: [String: Any] = [
            "senderId": senderId,
            "senderRole": senderRole,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]

        batch.setData(messageData, forDocument: messagesRef)

        // 2️⃣ Increment correct unread counter
        if senderRole == "customer" {
            batch.updateData([
                "unreadForBusiness": FieldValue.increment(Int64(1))
            ], forDocument: bookingRef)
        } else {
            batch.updateData([
                "unreadForCustomer": FieldValue.increment(Int64(1))
            ], forDocument: bookingRef)
        }

        batch.commit { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
