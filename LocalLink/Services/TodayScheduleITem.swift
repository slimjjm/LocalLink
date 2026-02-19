import Foundation

enum TodayScheduleItem: Identifiable {

    case booking(Booking)
    case blocked(BlockedTime)

    var id: String {
        switch self {
        case .booking(let b): return "booking_" + (b.id ?? UUID().uuidString)
        case .blocked(let b): return "blocked_" + (b.id ?? UUID().uuidString)
        }
    }

    var startDate: Date {
        switch self {
        case .booking(let b): return b.startDate
        case .blocked(let b): return b.startDate
        }
    }
}


