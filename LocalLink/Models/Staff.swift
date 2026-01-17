import Foundation
import FirebaseFirestoreSwift

struct Staff: Identifiable, Codable {

    @DocumentID var id: String?   // ✅ REQUIRED

    let name: String
    var isActive: Bool            // ✅ must be var (you toggle it)
    let skills: [String]
}
