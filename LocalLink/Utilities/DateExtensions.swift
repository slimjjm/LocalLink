import Foundation

extension Date {

    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    func atTime(_ time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")

        guard let parsedTime = formatter.date(from: time) else { return nil }

        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: self)
        let time = calendar.dateComponents([.hour, .minute], from: parsedTime)

        var final = DateComponents()
        final.year = day.year
        final.month = day.month
        final.day = day.day
        final.hour = time.hour
        final.minute = time.minute

        return calendar.date(from: final)
    }

    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
}
extension Date {

    /// Lowercased weekday key used for staff availability maps
    /// e.g. "monday", "tuesday"
    var weekdayKey: String {
        weekdayName.lowercased()
    }

    /// Alias used by booking validator
    func settingTime(from timeString: String) -> Date {
        atTime(timeString) ?? self
    }
}
