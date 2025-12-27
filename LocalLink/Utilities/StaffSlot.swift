import Foundation

struct StaffSlot: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
}
