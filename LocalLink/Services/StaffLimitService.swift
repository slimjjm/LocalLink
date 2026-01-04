import FirebaseFirestore

final class StaffLimitService {

    private let db = Firestore.firestore()

    /// Returns how many staff are currently used vs max allowed
    func fetchLimits(
        businessId: String,
        completion: @escaping (_ used: Int, _ max: Int) -> Void
    ) {

        let businessRef = db.collection("businesses").document(businessId)
        let staffRef = businessRef.collection("staff")

        businessRef.getDocument { businessSnap, _ in
            let data = businessSnap?.data() ?? [:]

            let allowed = data["staffSlotsAllowed"] as? Int ?? 1
            let purchased = data["staffSlotsPurchased"] as? Int ?? 0
            let maxAllowed = allowed + purchased

            staffRef.getDocuments { staffSnap, _ in
                let used = staffSnap?.documents.count ?? 0
                completion(used, maxAllowed)
            }
        }
    }
}
