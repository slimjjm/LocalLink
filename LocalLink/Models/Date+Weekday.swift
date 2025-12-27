import Foundation

extension Date {
    func weekdayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self).lowercased()
    }
}

