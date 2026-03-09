import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class EntitlementsRepository {

    private let db = Firestore.firestore()

    // ============================
    // GET ONCE
    // ============================

    func getEntitlements(businessId: String) async throws -> BusinessEntitlements {

        let doc = try await db
            .collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .getDocument()

        if let data = try? doc.data(as: BusinessEntitlements.self) {
            return data
        } else {
            // If doc does not exist yet, default to 1 free slot
            return BusinessEntitlements()
        }
    }

    // ============================
    // LIVE LISTENER
    // ============================

    func listenEntitlements(
        businessId: String,
        completion: @escaping (Result<BusinessEntitlements, Error>) -> Void
    ) -> ListenerRegistration {

        db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .addSnapshotListener { snapshot, error in

                if let error {
                    completion(.failure(error))
                    return
                }

                guard let snapshot else { return }

                if let data = try? snapshot.data(as: BusinessEntitlements.self) {
                    completion(.success(data))
                } else {
                    completion(.success(BusinessEntitlements()))
                }
            }
    }
}
