import Foundation
import FirebaseFirestoreSwift

struct Booking: Identifiable, Codable {

    @DocumentID var id: String?

    let businessId: String
    let customerId: String
    let ownerId: String

    let serviceId: String
    let serviceName: String
    let serviceDurationMinutes: Int

    /// Stored in pence (e.g. 2999 = £29.99)
    let price: Int

    let staffId: String
    let staffName: String

    let customerName: String
    let customerAddress: String

    let paymentIntentId: String?
    let refundId: String?
    let refundedAt: Date?

    /// Optional so older docs decode safely
    let isPaid: Bool?

    /// Optional “commercial day” (UK midnight) to avoid UTC drift
    let bookingDay: Date?

    /// (If you don’t actually use `date`, you can remove it later — but keep consistent with your writes)
    let date: Date
    let startDate: Date
    let endDate: Date

    let status: BookingStatus

    /// Optional so older docs decode safely
    let createdAt: Date?
}
