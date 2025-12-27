import Foundation

struct TimeSlot: Identifiable {
    let id = UUID()
    let staffId: String
    let staffName: String
    let start: Date
    let end: Date
}


