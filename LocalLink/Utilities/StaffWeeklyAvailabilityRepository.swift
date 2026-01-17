import Foundation
import FirebaseFirestore

final class StaffWeeklyAvailabilityRepository {

    private let db = Firestore.firestore()

    // MARK: - Fetch weekly availability

    func fetchWeek(
        businessId: String,
        staffId: String,
        completion: @escaping (Result<[String: StaffDayAvailability], Error>) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("weeklyAvailability")
            .getDocuments { snapshot, error in

                if let error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                var map: [String: StaffDayAvailability] = [:]

                snapshot?.documents.forEach { doc in
                    let key = doc.documentID.lowercased()
                    let data = doc.data()

                    let closed = data["closed"] as? Bool ?? false
                    let open = data["open"] as? String ?? "09:00"
                    let close = data["close"] as? String ?? "17:00"

                    map[key] = StaffDayAvailability(
                        open: open,
                        close: close,
                        closed: closed
                    )
                }

                DispatchQueue.main.async {
                    completion(.success(map))
                }
            }
    }

    // MARK: - Save weekly availability

    func saveWeek(
        businessId: String,
        staffId: String,
        week: [String: StaffDayAvailability],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let batch = db.batch()

        let baseRef = db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("weeklyAvailability")

        for (day, availability) in week {
            let ref = baseRef.document(day.lowercased())

            batch.setData(
                [
                    "open": availability.open,
                    "close": availability.close,
                    "closed": availability.closed
                ],
                forDocument: ref,
                merge: true
            )
        }

        batch.commit { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

