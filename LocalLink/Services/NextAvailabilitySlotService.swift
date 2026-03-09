import Foundation
import FirebaseFirestore

final class NextAvailableSlotService {

    private let db = Firestore.firestore()

    func fetchNextSlot(
        businessId: String,
        completion: @escaping (Date?) -> Void
    ) {

        let now = Date()

        db.collectionGroup("availableSlots")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("isBooked", isEqualTo: false)
            .whereField("startTime", isGreaterThan: Timestamp(date: now))
            .order(by: "startTime")
            .limit(to: 1)
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ Next slot error:", error.localizedDescription)
                    completion(nil)
                    return
                }

                guard
                    let doc = snapshot?.documents.first,
                    let ts = doc["startTime"] as? Timestamp
                else {
                    completion(nil)
                    return
                }

                completion(ts.dateValue())
            }
    }
}
