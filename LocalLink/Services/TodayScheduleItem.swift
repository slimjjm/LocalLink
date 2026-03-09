import Foundation

enum TodayScheduleItem: Identifiable {

    case booking(Booking)
    case timeBlock(TimeBlockItem)
    case dayBlock(DayBlockItem)

    var id: String {
        switch self {
        case .booking(let b):
            return "booking_" + (b.id ?? UUID().uuidString)
        case .timeBlock(let t):
            return "time_" + t.id
        case .dayBlock(let d):
            return "day_" + d.id
        }
    }

    var startDate: Date {
        switch self {
        case .booking(let b): return b.startDate
        case .timeBlock(let t): return t.startDate
        case .dayBlock(let d): return d.startDate
        }
    }
}

// Lightweight wrappers that carry the doc id for delete actions.
struct TimeBlockItem: Identifiable {
    let id: String
    let staffId: String
    let title: String
    let startDate: Date
    let endDate: Date
}

struct DayBlockItem: Identifiable {
    let id: String
    let staffId: String
    let reason: String
    let startDate: Date
    let endDate: Date
}


