import Foundation

// One business-level day (stored in Firestore)
struct EditableDay: Identifiable, Codable {

    // Firestore-safe stable ID, e.g. "monday"
    let id: String

    var start: String   // "09:00"
    var end: String     // "17:00"
    var closed: Bool
}

// Container saved on businesses/{businessId}
struct BusinessAvailability: Codable {

    var capacity: Int        // bookings per slot
    var slotInterval: Int    // minutes

    // Key = "monday", "tuesday", etc
    var days: [String: EditableDay]
}
