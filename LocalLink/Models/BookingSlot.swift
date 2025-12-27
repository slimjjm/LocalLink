import Foundation

struct BookingSlot: Identifiable, Hashable {
    let id = UUID()
    let start: Date
    let end: Date
    let isAvailable: Bool
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: start)
    }
}
