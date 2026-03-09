import Foundation
import FirebaseFirestoreSwift

struct AvailableSlot: Identifiable, Codable {

    @DocumentID var id: String?

    let businessId: String
    let staffId: String

    let startTime: Date
    let endTime: Date

    let isBooked: Bool
}
