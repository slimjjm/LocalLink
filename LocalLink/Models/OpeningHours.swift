import FirebaseFirestoreSwift

struct OpeningHours: Codable {

    let isOpen: Bool
    let open: String?
    let close: String?

}
