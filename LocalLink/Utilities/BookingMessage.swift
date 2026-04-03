import Foundation
import FirebaseFirestoreSwift

struct BookingMessage: Identifiable, Codable {

    let id: String
    
    let senderName: String?
    let senderId: String
    let senderRole: String
    let text: String
    let createdAt: Date?
}
