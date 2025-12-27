import FirebaseFirestoreSwift

struct Staff: Identifiable, Codable {
    @DocumentID var id: String?

    let name: String
    let skills: [String]
    let isActive: Bool
}
