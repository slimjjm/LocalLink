import Foundation
import FirebaseFirestoreSwift

struct BusinessService: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    let name: String
    let details: String?
    let price: Double
    let durationMinutes: Int

    // NEW: where the service happens
    // "in_store" (default) or "mobile"
    let locationType: String?

    // Optional so older docs decode safely
    let isActive: Bool?
    let createdAt: Date?
}
