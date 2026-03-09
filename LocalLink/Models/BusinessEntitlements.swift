import Foundation
import FirebaseFirestoreSwift

struct BusinessEntitlements: Codable {
    var freeStaffSlots: Int = 1
    var extraStaffSlots: Int = 0

    var totalAllowedStaff: Int {
        max(1, freeStaffSlots + extraStaffSlots)
    }
}
