import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class BlockConflictService {

    private let db = Firestore.firestore()

    // =================================================
    // FETCH CONFLICTS
    // =================================================
    func fetchConflictingBookings(
        businessId: String,
        staffId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [BookingConflict] {

        print("🚨 Checking conflicts...")
        print("🟡 Block Start:", startDate)
        print("🟡 Block End:", endDate)

        let snapshot = try await db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .getDocuments()

        print("📦 Confirmed bookings fetched:", snapshot.documents.count)

        var conflicts: [BookingConflict] = []

        for doc in snapshot.documents {

            guard
                let startTS = doc["startDate"] as? Timestamp,
                let endTS = doc["endDate"] as? Timestamp,
                let customerName = doc["customerName"] as? String,
                let serviceName = doc["serviceName"] as? String
            else {
                print("⚠️ Skipping booking \(doc.documentID) — missing fields")
                continue
            }

            let bookingStart = startTS.dateValue()
            let bookingEnd = endTS.dateValue()

            print("🔎 Comparing booking:")
            print("   🕒 Booking Start:", bookingStart)
            print("   🕒 Booking End:", bookingEnd)

            // REAL overlap check
            let overlaps =
                bookingStart < endDate &&
                bookingEnd > startDate

            print("   🔁 Overlaps?", overlaps)

            if overlaps {
                print("   ✅ Conflict detected with booking:", doc.documentID)

                conflicts.append(
                    BookingConflict(
                        id: doc.documentID,
                        customerName: customerName,
                        serviceName: serviceName,
                        startDate: bookingStart,
                        endDate: bookingEnd
                    )
                )
            }
        }

        print("🚩 Total conflicts found:", conflicts.count)

        return conflicts
    }

    // =================================================
    // CANCEL BOOKINGS (BATCHED)
    // =================================================
    func cancelBookings(
        conflicts: [BookingConflict],
        staffId: String,
        blockId: String
    ) async throws {

        guard !conflicts.isEmpty else {
            print("⚠️ cancelBookings called with empty conflicts")
            return
        }

        print("🛑 Cancelling \(conflicts.count) booking(s)")

        let batch = db.batch()

        for conflict in conflicts {

            let ref = db.collection("bookings").document(conflict.id)

            print("❌ Cancelling booking:", conflict.id)

            batch.updateData([
                "status": BookingStatus.cancelled_by_business.rawValue,
                "cancelReason": "Blocked time",
                "cancelledAt": FieldValue.serverTimestamp(),
                "cancelledByStaffId": staffId,
                "blockReferenceId": blockId
            ], forDocument: ref)
        }

        try await batch.commit()

        print("✅ Bookings cancelled successfully")
    }
}
