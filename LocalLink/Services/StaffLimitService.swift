import FirebaseFirestore

final class StaffLimitService {

    private let db = Firestore.firestore()

    func canAddStaff(
        businessId: String,
        completion: @escaping (Bool, Int, Int) -> Void
    ) {
        let businessRef = db.collection("businesses").document(businessId)
        let staffRef = businessRef.collection("staff")

        businessRef.getDocument { businessSnap, _ in
            let data = businessSnap?.data() ?? [:]

            let allowed = data["staffSlotsAllowed"] as? Int ?? 1
            let purchased = data["staffSlotsPurchased"] as? Int ?? 0
            let maxAllowed = allowed + purchased

            staffRef.getDocuments { staffSnap, _ in
                let currentCount = staffSnap?.documents.count ?? 0
                completion(currentCount < maxAllowed, currentCount, maxAllowed)
            }
        }
    }
}
