import SwiftUI

struct WeeklyAvailability: Identifiable {
    let id: String          // monday, tuesday, etc
    let enabled: Bool
    let start: String?
    let end: String?
}
