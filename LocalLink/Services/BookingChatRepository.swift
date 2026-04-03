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
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(
                domain: "Auth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )))
            return
        }

        let messageRef = db.collection("bookings")
            .document(bookingId)
            .collection("messages")
            .document()

        let bookingRef = db.collection("bookings").document(bookingId)
        let businessRef = db.collection("businesses").document(businessId)

        // 🔥 Fetch business name FIRST (so senderName is always correct)
        businessRef.getDocument { snapshot, error in
            
            if let error {
                completion(.failure(error))
                return
            }

            let businessName = snapshot?.data()?["name"] as? String ?? "Business"

            // ✅ Determine sender name
            let senderName: String = {
                if senderRole == "customer" {
                    return user.displayName ?? "Customer"
                } else {
                    return businessName
                }
            }()

            let data: [String: Any] = [
                "senderId": user.uid,
                "senderRole": senderRole,
                "senderName": senderName,
                "text": text,
                "createdAt": FieldValue.serverTimestamp()
            ]

            // 🔥 Write message
            messageRef.setData(data) { error in
                if let error {
                    completion(.failure(error))
                    return
                }

                // 🔥 Update unread counters safely
                if senderRole == "customer" {
                    bookingRef.updateData([
                        "unreadForBusiness": FieldValue.increment(Int64(1))
                    ])
                } else {
                    bookingRef.updateData([
                        "unreadForCustomer": FieldValue.increment(Int64(1))
                    ])
                }

                completion(.success(()))
            }
        }
    }
}
