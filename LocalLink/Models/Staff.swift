import Foundation
import FirebaseFirestoreSwift

struct Staff: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let isActive: Bool
    let skills: [String]?
}



