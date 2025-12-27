import FirebaseFirestoreSwift
import Foundation

struct Service: Identifiable, Codable {

    @DocumentID var id: String?

    let name: String
    let details: String?
    let price: Double
    let durationMinutes: Int
    let isActive: Bool

    // Optional — avoids decode failures
    let createdAt: Date?
}

