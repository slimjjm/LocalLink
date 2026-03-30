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
            .whereField("startTime", isGreaterThan: Timestamp(date: now))
            .order(by: "startTime")
            .limit(to: 10)
            .getDocuments { snapshot, error in

                // ❌ Firestore error
                if let error = error {
                    print("❌ Next slot error:", error.localizedDescription)
                    completion(nil)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents returned at all")
                    completion(nil)
                    return
                }

                print("📊 Documents fetched:", documents.count)

                // 🔍 Inspect raw data
                documents.forEach { doc in
                    print("📦 Slot:", doc.data())
                }

                // ✅ Handle BOTH old (0) and new (false)
                let validSlot = documents.first(where: { doc in
                    let data = doc.data()

                    if let isBooked = data["isBooked"] as? Bool {
                        return isBooked == false
                    }

                    if let isBookedInt = data["isBooked"] as? Int {
                        return isBookedInt == 0
                    }

                    return false
                })

                print("✅ Valid slot found:", validSlot != nil)

                guard
                    let slot = validSlot,
                    let ts = slot["startTime"] as? Timestamp
                else {
                    print("⚠️ No valid available slot after filtering")
                    completion(nil)
                    return
                }

                let date = ts.dateValue()
                print("🎯 Returning next slot:", date)

                completion(date)
            }
    }
}
