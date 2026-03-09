import Foundation
import FirebaseFirestoreSwift

struct TimeBlock: Identifiable, Codable {

    @DocumentID var id: String?

    var staffId: String
    var startDate: Date
    var endDate: Date
    var title: String
}
