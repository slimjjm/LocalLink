import Foundation

extension Date {

    // MARK: - Time math

    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    // MARK: - Firestore helpers

    /// yyyy-MM-dd
    func dateId() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    // MARK: - Time parsing

    func atTime(_ hhmm: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"

        guard let parsed = f.date(from: hhmm) else { return nil }

        let cal = Calendar.current
        let day = cal.dateComponents([.year, .month, .day], from: self)
        let time = cal.dateComponents([.hour, .minute], from: parsed)

        var final = DateComponents()
        final.year = day.year
        final.month = day.month
        final.day = day.day
        final.hour = time.hour
        final.minute = time.minute

        return cal.date(from: final)
    }
}
import Foundation

extension Date {
    func dayId() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}

enum TimeHHmm {
    static func isValid(_ s: String) -> Bool {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...23).contains(h),
              (0...59).contains(m)
        else { return false }
        return true
    }
}

