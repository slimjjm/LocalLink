import Foundation
import FirebaseFirestoreSwift

struct StaffAvailability: Identifiable, Codable {

    @DocumentID var id: String?   // day name (monday, etc)

    var isWorking: Bool
    var start: String
    var end: String
}

