import Foundation
import SwiftUI

enum BookingStatus: String, Codable, Equatable {
    
    case pending_payment
    case confirmed
    case completed
    case cancelled_by_business
    case cancelled_by_customer
    case refunded
    
    // MARK: - UI Logic
    
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
