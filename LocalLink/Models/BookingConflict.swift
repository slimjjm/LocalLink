import Foundation

struct BookingConflict: Identifiable {
    let id: String
    let customerName: String
    let serviceName: String
    let startDate: Date
    let endDate: Date
}
