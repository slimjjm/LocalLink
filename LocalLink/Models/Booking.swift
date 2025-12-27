import Foundation
import FirebaseFirestoreSwift

struct Booking: Identifiable, Codable {

    @DocumentID var id: String?   // ✅ THIS IS THE FIX

    let businessId: String
    let customerId: String

    let serviceId: String
    let serviceName: String
    let serviceDurationMinutes: Int
    let price: Double

    let staffId: String
    let staffName: String

    let date: Date
    let startDate: Date
    let endDate: Date

    let status: BookingStatus
    let createdAt: Date
}
