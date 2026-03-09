import Foundation
import FirebaseFirestore

final class SlotPurgeService {

    private let db = Firestore.firestore()

    func purgeSlots(
        businessId: String,
        staffId: String,
        startDate: Date,
        endDate: Date
    ) async throws {

        print("🧹 Purging slots for block window")

        let slotsRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availableSlots")

        let snapshot = try await slotsRef
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startTime", isLessThan: Timestamp(date: endDate))
            .getDocuments()

        guard !snapshot.documents.isEmpty else {
            print("⚠️ No slots found to purge")
            return
        }

        let batch = db.batch()

        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()

        print("✅ Slots purged successfully")
    }
}
