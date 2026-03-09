import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Business: Identifiable, Codable {

    @DocumentID var id: String?

    let businessName: String
    let address: String?

    let town: String
    let category: String

    let isMobile: Bool
    let serviceTowns: [String]

    let isActive: Bool
    let verified: Bool
    let createdAt: Timestamp
}
