import Foundation

enum DayKey: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
extension DayKey {

    /// Converts Calendar weekday (1 = Sunday … 7 = Saturday) into DayKey
    static func fromCalendarWeekday(_ weekday: Int) -> DayKey {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default:
            return .monday
        }
    }
}
