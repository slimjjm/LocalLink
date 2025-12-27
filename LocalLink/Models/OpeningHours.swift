import Foundation

struct OpeningHour: Codable {
    var open: String
    var close: String
    var closed: Bool
}

struct OpeningHours: Codable {
    var monday: OpeningHour
    var tuesday: OpeningHour
    var wednesday: OpeningHour
    var thursday: OpeningHour
    var friday: OpeningHour
    var saturday: OpeningHour
    var sunday: OpeningHour
}

extension OpeningHours {
    static var defaultHours: OpeningHours {
        OpeningHours(
            monday: .init(open: "09:00", close: "17:00", closed: false),
            tuesday: .init(open: "09:00", close: "17:00", closed: false),
            wednesday: .init(open: "09:00", close: "17:00", closed: false),
            thursday: .init(open: "09:00", close: "17:00", closed: false),
            friday: .init(open: "09:00", close: "17:00", closed: false),
            saturday: .init(open: "09:00", close: "13:00", closed: false),
            sunday: .init(open: "", close: "", closed: true)
        )
    }
}
