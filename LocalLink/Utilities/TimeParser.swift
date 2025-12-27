import Foundation

struct TimeParser {

    static func date(
        on baseDate: Date,
        timeString: String
    ) -> Date? {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")

        guard let time = formatter.date(from: timeString) else {
            return nil
        }

        let calendar = Calendar.current

        let timeComponents = calendar.dateComponents(
            [.hour, .minute],
            from: time
        )

        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: baseDate
        )
    }
}

