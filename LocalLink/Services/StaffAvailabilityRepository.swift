import FirebaseFirestore
import FirebaseFirestoreSwift

final class StaffAvailabilityRepository {

    private let db = Firestore.firestore()

    func fetchAvailability(
        businessId: String,
        staffId: String,
        completion: @escaping ([String: StaffDayAvailability]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snapshot, _ in

                guard
                    let data = snapshot?.data(),
                    let availability = data["availability"] as? [String: Any]
                else {
                    completion([:])
                    return
                }

                var result: [String: StaffDayAvailability] = [:]

                for (day, value) in availability {
                    guard
                        let map = value as? [String: Any],
                        let open = map["open"] as? String,
                        let close = map["close"] as? String,
                        let closed = map["closed"] as? Bool
                    else { continue }

                    result[day] = StaffDayAvailability(
                        open: open,
                        close: close,
                        closed: closed
                    )
                }

                completion(result)
            }
    }
}
