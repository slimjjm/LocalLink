import Foundation
import SwiftUI

enum BookingStatus: Codable, Equatable {

    case pendingPayment
    case confirmed
    case completed
    case cancelledByBusiness
    case cancelledByCustomer
    case refunded
    case unknown(String)
}

// MARK: - Codable
extension BookingStatus {

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value {
        case "pending_payment":
            self = .pendingPayment
        case "confirmed":
            self = .confirmed
        case "completed":
            self = .completed
        case "cancelled_by_business":
            self = .cancelledByBusiness
        case "cancelled_by_customer":
            self = .cancelledByCustomer
        case "refunded":
            self = .refunded
        default:
            self = .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .pendingPayment: return "pending_payment"
        case .confirmed: return "confirmed"
        case .completed: return "completed"
        case .cancelledByBusiness: return "cancelled_by_business"
        case .cancelledByCustomer: return "cancelled_by_customer"
        case .refunded: return "refunded"
        case .unknown(let value): return value
        }
    }
}

// MARK: - UI Logic
extension BookingStatus {

    var isPaid: Bool {
        switch self {
        case .confirmed, .completed:
            return true
        default:
            return false
        }
    }

    var paymentBadgeText: String? {
        isPaid ? "PAID" : nil
    }

    var paymentBadgeColor: Color {
        isPaid ? .green : .clear
    }
}
