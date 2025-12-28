import FirebaseFirestoreSwift

struct StaffDayAvailability: Codable {
    let closed: Bool
    let start: String?
    let end: String?
}
