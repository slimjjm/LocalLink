import FirebaseFirestore
import FirebaseFirestoreSwift

final class BusinessServiceRepository {

    private let db = Firestore.firestore()

    func fetchServices(
        businessId: String,
        completion: @escaping ([BusinessService]) -> Void
    ) {

        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ services fetch:", error)
                    completion([])
                    return
                }

                let services =
                    snapshot?.documents.compactMap {
                        try? $0.data(as: BusinessService.self)
                    } ?? []

                completion(services)
            }
    }
}
