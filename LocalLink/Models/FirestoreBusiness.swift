import FirebaseFirestoreSwift

struct FirestoreBusiness: Identifiable, Codable {
    @DocumentID var id: String?
    let businessName: String
    let address: String
}
