import FirebaseFirestore

final class AvailabilityRepository {

    private let db = Firestore.firestore()

    func fetchAvailability(
        businessId: String,
        completion: @escaping (Availability?) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in

                guard
                    let data = snapshot?.data(),
                    let availabilityData = data["availability"]
                else {
                    completion(nil)
                    return
                }

                do {
                    let json = try JSONSerialization.data(withJSONObject: availabilityData)
                    let availability = try JSONDecoder().decode(Availability.self, from: json)
                    completion(availability)
                } catch {
                    print("Availability decode error:", error)
                    completion(nil)
                }
            }
    }
}
