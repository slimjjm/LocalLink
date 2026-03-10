import Foundation
import FirebaseFirestoreSwift

struct BookingMessage: Identifiable, Codable {

    @DocumentID var id: String?

    let senderId: String
    let senderRole: String
    let text: String
    let createdAt: Date?
}
