import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Staff: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    let name: String

    var serviceIds: [String]?
    var skills: [String]?
    var isActive: Bool
    var createdAt: Date

    // 🔑 NEW — staff priority for subscription entitlement
    var seatRank: Int?

    static func == (lhs: Staff, rhs: Staff) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
