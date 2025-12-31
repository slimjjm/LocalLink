import Foundation
import FirebaseFirestoreSwift

struct BusinessService: Identifiable, Codable {

    @DocumentID var id: String?

    let name: String
    let details: String?
    let price: Double
    let durationMinutes: Int

    // Optional so older docs decode safely
    let isActive: Bool?
    let createdAt: Date?
}

