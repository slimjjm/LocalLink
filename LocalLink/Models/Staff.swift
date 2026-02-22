import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Staff: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    let name: String

    var serviceIds: [String]?   // ← what skills they can perform
    var skills: [String]?       // optional display
    var isActive: Bool
    var createdAt: Date?

    static func == (lhs: Staff, rhs: Staff) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
