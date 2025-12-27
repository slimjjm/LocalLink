import Foundation

enum AvailabilityValidationError: LocalizedError {
    case closedDayHasTimes
    case invalidTimeRange(day: String)

    var errorDescription: String? {
        switch self {
        case .closedDayHasTimes:
            return "Closed days cannot have opening hours."
        case .invalidTimeRange(let day):
            return "\(day.capitalized): closing time must be later than opening time."
        }
    }
}

struct AvailabilityValidator {

    static func validate(day: EditableDay) throws {

        if day.closed {
            // Closed day must not be validated further
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard
            let open = formatter.date(from: day.start),
            let close = formatter.date(from: day.end),
            close > open
        else {
            throw AvailabilityValidationError.invalidTimeRange(day: day.day)
        }
    }
}

