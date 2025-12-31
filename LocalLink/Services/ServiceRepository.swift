import FirebaseFirestore
import FirebaseFirestoreSwift

final class ServiceRepository {

    private let db = Firestore.firestore()

    func fetchServices(
        businessId: String,
        completion: @escaping ([BusinessService]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snapshot, error in

                if let snapshot {
                    let services = snapshot.documents.compactMap {
                        try? $0.data(as: BusinessService.self)
                    }
                    completion(services)
                } else {
                    completion([])
                }
            }
    }
}
