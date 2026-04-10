import Foundation
import FirebaseFirestore   // ✅ ADD THIS
import FirebaseFirestoreSwift

struct BusinessService: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    let name: String
    let details: String?
    let price: Double
    let durationMinutes: Int

    let locationType: String?
    let isActive: Bool?
    
    let createdAt: Timestamp?   // ✅ now works
}
