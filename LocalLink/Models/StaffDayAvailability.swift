import Foundation

struct StaffDayAvailability: Codable {
    let open: String     // "HH:mm"
    let close: String    // "HH:mm"
    let closed: Bool
}
