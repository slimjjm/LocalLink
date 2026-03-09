import Foundation
import FirebaseFirestoreSwift

struct BookingMessage: Identifiable, Codable {

    @DocumentID var id: String?

    let senderId: String
    let senderRole: String   // "customer" or "business"
    let text: String
    let createdAt: Date

}
