import Foundation

enum BookingStatus: String, Codable {
    case pendingPayment = "pending_payment"
    case confirmed
    case completed
    case cancelledByBusiness = "cancelled_by_business"
    case cancelledByCustomer = "cancelled_by_customer"
    case refunded
}


