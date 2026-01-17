import FirebaseFirestore
import FirebaseFirestoreSwift

final class StaffRepository {

    private let db = Firestore.firestore()

    // MARK: - Fetch ALL staff (ordered, deterministic)

    func fetchAllStaff(
        businessId: String,
        completion: @escaping ([Staff]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .order(by: "name")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ fetchAllStaff error:", error.localizedDescription)
                    completion([])
                    return
                }

                let staff =
                    snapshot?.documents.compactMap {
                        try? $0.data(as: Staff.self)
                    } ?? []

                completion(staff)
            }
    }

    // MARK: - Create staff (SAFE)

    func createStaff(
        businessId: String,
        staff: Staff,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            try db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .addDocument(from: staff) { error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Update active flag ONLY

    func updateStaffActive(
        businessId: String,
        staffId: String,
        isActive: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .updateData([
                "isActive": isActive
            ]) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}
