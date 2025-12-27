import Foundation
import FirebaseFirestoreSwift

struct CustomerProfile: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var phone: String
    var createdAt: Date?
}
