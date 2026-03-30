import Foundation

enum DurationFormatter {
    static func text(from totalMinutes: Int) -> String {
        guard totalMinutes > 0 else { return "0 min" }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return hours == 1 ? "1h \(minutes)m" : "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return hours == 1 ? "1h" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
