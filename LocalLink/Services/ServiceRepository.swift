import FirebaseFirestore
import FirebaseFirestoreSwift

final class ServiceRepository {

    private let db = Firestore.firestore()

    func fetchService(
        businessId: String,
        serviceId: String,
        completion: @escaping (Service?) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snapshot, error in

                guard
                    let snapshot,
                    snapshot.exists,
                    let service = try? snapshot.data(as: Service.self)
                else {
                    completion(nil)
                    return
                }

                completion(service)
            }
    }
}
