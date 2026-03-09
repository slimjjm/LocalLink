import Foundation
import FirebaseFirestoreSwift

struct DayBlock: Identifiable, Codable {

    @DocumentID var id: String?

    var staffId: String
    var startDate: Date
    var endDate: Date
    var reason: String
}
