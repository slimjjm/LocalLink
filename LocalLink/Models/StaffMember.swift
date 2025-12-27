import Foundation
import FirebaseFirestoreSwift

struct StaffMember: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    let name: String
    let isActive: Bool
    let skills: [String]              // service IDs
    
    let weeklyAvailability: WeeklyAvailability
    
    let createdAt: Date?
}
