import Foundation

enum AvailabilityValidationError: LocalizedError {
    case invalidTimeRange(day: String)

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange(let day):
            return "\(day.capitalized): closing time must be later than opening time."
        }
    }
}

struct AvailabilityValidator {

    static func validate(day: StaffEditableDay) throws {
        guard !day.closed else { return }

        guard day.closeTime > day.openTime else {
            throw AvailabilityValidationError.invalidTimeRange(
                day: day.key.rawValue
            )
        }
    }
}
