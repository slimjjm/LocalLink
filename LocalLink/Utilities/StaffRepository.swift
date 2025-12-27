import FirebaseFirestore

final class StaffRepository {

    private let db = Firestore.firestore()

    func fetchActiveStaff(
        businessId: String,
        completion: @escaping ([Staff]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, _ in
                let staff = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []

                completion(staff)
            }
    }
}
