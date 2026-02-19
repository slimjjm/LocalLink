import Foundation
import FirebaseFirestoreSwift

struct Booking: Identifiable, Codable {

    @DocumentID var id: String?

    let businessId: String
    let customerId: String
    let ownerId: String

    let location: String

    let serviceId: String
    let serviceName: String
    let serviceDurationMinutes: Int
    let price: Double

    let staffId: String
    let staffName: String

    let customerName: String
    let customerAddress: String

    let paymentIntentId: String

    // Refund polish
    let refundId: String?
    let refundedAt: Date?

    let date: Date
    let startDate: Date
    let endDate: Date

    let status: BookingStatus
    let createdAt: Date

    var isPaid: Bool { !paymentIntentId.isEmpty }
    var isRefunded: Bool { status == .refunded }
}
