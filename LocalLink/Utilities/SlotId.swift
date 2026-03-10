import Foundation

enum SlotID {

    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func make(from date: Date) -> String {
        formatter.string(from: date)
    }
}
