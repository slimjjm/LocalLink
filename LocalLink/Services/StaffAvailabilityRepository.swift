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
            .collection("availability")
            .getDocuments { snapshot, error in

                var result: [String: StaffDayAvailability] = [:]

                guard let documents = snapshot?.documents else {
                    completion(result)
                    return
                }

                for doc in documents {
                    if let availability = try? doc.data(as: StaffDayAvailability.self) {
                        result[doc.documentID] = availability
                    }
                }

                completion(result)
            }
    }
}
