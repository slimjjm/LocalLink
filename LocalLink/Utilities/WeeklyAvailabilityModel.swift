import Foundation

// MARK: - Editable Day Availability

struct EditableDayAvailability: Codable {
    var open: String
    var close: String
    var closed: Bool
}

// MARK: - Editable Weekly Availability

struct EditableWeeklyAvailability: Codable {
    var monday: EditableDayAvailability
    var tuesday: EditableDayAvailability
    var wednesday: EditableDayAvailability
    var thursday: EditableDayAvailability
    var friday: EditableDayAvailability
    var saturday: EditableDayAvailability
    var sunday: EditableDayAvailability

    static func defaultClosed() -> EditableWeeklyAvailability {
        let closed = EditableDayAvailability(
            open: "09:00",
            close: "17:00",
            closed: true
        )

        return EditableWeeklyAvailability(
            monday: closed,
            tuesday: closed,
            wednesday: closed,
            thursday: closed,
            friday: closed,
            saturday: closed,
            sunday: closed
        )
    }
}

// MARK: - Helpers

extension EditableWeeklyAvailability {
    func day(for weekday: String) -> EditableDayAvailability {
        switch weekday {
        case "monday": return monday
        case "tuesday": return tuesday
        case "wednesday": return wednesday
        case "thursday": return thursday
        case "friday": return friday
        case "saturday": return saturday
        case "sunday": return sunday
        default: return EditableDayAvailability.closedDay()
        }
    }
}

extension EditableDayAvailability {
    static func closedDay() -> EditableDayAvailability {
        EditableDayAvailability(
            open: "09:00",
            close: "17:00",
            closed: true
        )
    }
}
