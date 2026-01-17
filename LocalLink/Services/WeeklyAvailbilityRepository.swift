import SwiftUI
import FirebaseFirestore

final class StaffScheduleRepository {

    private let db = Firestore.firestore()

    func fetchWeeklyAvailability(
        businessId: String,
        staffId: String,
        completion: @escaping ([WeeklyAvailability]) -> Void
    ) {

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("weeklyAvailability")
            .getDocuments { snapshot, _ in

                let days = snapshot?.documents.map { doc in
                    let data = doc.data()
                    return WeeklyAvailability(
                        id: doc.documentID,
                        enabled: data["enabled"] as? Bool ?? false,
                        start: data["start"] as? String,
                        end: data["end"] as? String
                    )
                } ?? []

                completion(days)
            }
    }
}

