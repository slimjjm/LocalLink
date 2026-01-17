import Foundation

extension Date {

    /// Combines a date (yyyy-MM-dd) with a time string ("HH:mm")
    static func combine(date: Date, time: String) -> Date? {
        let calendar = Calendar.current

        let timeParts = time.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        )
    }
}
