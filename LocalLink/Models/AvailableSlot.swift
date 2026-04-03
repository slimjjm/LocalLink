import Foundation
import FirebaseFirestoreSwift

struct AvailableSlot: Identifiable, Codable {

    @DocumentID var id: String?

    let businessId: String
    let staffId: String

    let startTime: Date
    let endTime: Date

    let isBooked: Bool

    // ✅ SAFE ACCESSOR (THIS IS KEY)
    var safeId: String {
        guard let id else {
            fatalError("❌ Slot missing documentID")
        }
        return id
    }
}
