import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Business: Identifiable, Codable {

    @DocumentID var id: String?

    let businessName: String
    let address: String?        // ✅ optional for now
    let isActive: Bool
    let verified: Bool
    let createdAt: Timestamp
}

