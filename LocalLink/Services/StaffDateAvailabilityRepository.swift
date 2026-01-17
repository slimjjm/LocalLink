import FirebaseFirestore

struct StaffDateAvailability {
    let startTime: Date
    let endTime: Date
}

final class StaffDateAvailabilityRepository {

    private let db = Firestore.firestore()

    func fetchAvailability(
        businessId: String,
        staffId: String,
        date: Date,
        completion: @escaping (StaffDateAvailability?) -> Void
    ) {
        let dayId = date.dateId()

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availability")
            .document(dayId)
            .getDocument { snapshot, _ in

                guard
                    let data = snapshot?.data(),
                    let start = data["startTime"] as? Timestamp,
                    let end = data["endTime"] as? Timestamp
                else {
                    completion(nil)
                    return
                }

                completion(
                    StaffDateAvailability(
                        startTime: start.dateValue(),
                        endTime: end.dateValue()
                    )
                )
            }
    }
}
