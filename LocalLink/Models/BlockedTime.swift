import Foundation
import FirebaseFirestoreSwift

struct BlockedTime: Identifiable, Codable {

    @DocumentID var id: String?

    let businessId: String
    let staffId: String?

    let title: String
    let startDate: Date
    let endDate: Date

    let repeatType: String        // "none", "daily", "weekly", "monthly"
    let repeatUntil: Date?        // optional end date

    let createdAt: Date
}
