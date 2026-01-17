import Foundation

extension Date {

    /// "monday", "tuesday", etc (Firestore weekly keys)
    var weekdayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self).lowercased()
    }

    /// Legacy / UI-friendly helper (safe to keep)
    func weekdayString() -> String {
        weekdayKey
    }
}
