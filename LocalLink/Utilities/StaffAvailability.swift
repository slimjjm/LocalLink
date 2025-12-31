import Foundation
import FirebaseFirestoreSwift

struct StaffAvailability: Codable {
    let monday: StaffDayAvailability?
    let tuesday: StaffDayAvailability?
    let wednesday: StaffDayAvailability?
    let thursday: StaffDayAvailability?
    let friday: StaffDayAvailability?
    let saturday: StaffDayAvailability?
    let sunday: StaffDayAvailability?
}

struct StaffDayAvailability: Codable {
    let open: String
    let close: String
    let closed: Bool
}
