import Foundation

struct AvailabilityDateHelper {

    static func isDateAvailable(
        _ date: Date,
        availability: Availability
    ) -> Bool {

        let weekday = Calendar.current.weekdaySymbols[
            Calendar.current.component(.weekday, from: date) - 1
        ].lowercased()

        guard let day = availability.days[weekday] else {
            return false
        }

        return day.closed == false
    }
}
