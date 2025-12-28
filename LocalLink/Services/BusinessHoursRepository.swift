import FirebaseFirestore

final class BusinessHoursRepository {

    private let db = Firestore.firestore()

    func fetchHours(
        businessId: String,
        completion: @escaping ([String: OpeningHours]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("hours")
            .getDocuments { snapshot, _ in

                var result: [String: OpeningHours] = [:]

                snapshot?.documents.forEach { doc in
                    if let hours = try? doc.data(as: OpeningHours.self) {
                        result[doc.documentID] = hours
                    }
                }

                completion(result)
            }
    }
}
