import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct SlotGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    func generateSlotsForDay(
        businessId: String,
        staffId: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        blockedTimes: [BlockedTime],
        intervalMinutes: Int = 30
    ) async throws {

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        let slotCollection = staffRef.collection("availableSlots")

        print("🔄 Regenerating slots for:", date)

        // =========================================
        // STEP 0 — CANCEL CONFLICTING BOOKINGS
        // =========================================

        let bookingsSnapshot = try await db
            .collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .whereField("status", isEqualTo: "confirmed")
            .getDocuments()

        for bookingDoc in bookingsSnapshot.documents {

            guard
                let startTS = bookingDoc["startDate"] as? Timestamp,
                let endTS   = bookingDoc["endDate"]   as? Timestamp
            else {
                print("⚠️ Booking missing startDate/endDate:", bookingDoc.documentID)
                continue
            }

            let bookingStart = startTS.dateValue()
            let bookingEnd   = endTS.dateValue()

            let overlapsBlockedTime = blockedTimes.contains {
                bookingStart < $0.endDate && bookingEnd > $0.startDate
            }

            if overlapsBlockedTime {

                print("🚨 BOOKING OVERLAPS BLOCK:", bookingDoc.documentID)

                try await db
                    .collection("bookings")
                    .document(bookingDoc.documentID)
                    .updateData([
                        "status": "cancelled_by_business",
                        "cancelReason": "staff_unavailable",
                        "cancelledAt": FieldValue.serverTimestamp()
                    ])

                print("❌ Booking cancelled:", bookingDoc.documentID)
            }
        }

        // =========================================
        // STEP 1 — DELETE EXISTING SLOTS FOR DAY
        // =========================================

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let existingSlots = try await slotCollection
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("startTime", isLessThan: Timestamp(date: endOfDay))
            .getDocuments()

        var deleteBatch = db.batch()
        var deleteCount = 0

        for doc in existingSlots.documents {

            deleteBatch.deleteDocument(doc.reference)
            deleteCount += 1

            if deleteCount == 450 {
                try await deleteBatch.commit()
                deleteBatch = db.batch()
                deleteCount = 0
            }
        }

        if deleteCount > 0 {
            try await deleteBatch.commit()
        }

        print("🗑 Deleted existing slots:", existingSlots.count)

        // =========================================
        // STEP 2 — BUILD NEW SLOTS
        // =========================================

        let slots = SlotBuilder.buildSlots(
            date: date,
            startTime: startTime,
            endTime: endTime,
            intervalMinutes: intervalMinutes
        )

        var writeBatch = db.batch()
        var writeCount = 0

        for slotStart in slots {

            guard let slotEnd = calendar.date(
                byAdding: .minute,
                value: intervalMinutes,
                to: slotStart
            ) else { continue }

            let isBlocked = blockedTimes.contains {
                slotStart < $0.endDate && slotEnd > $0.startDate
            }

            if isBlocked {
                print("🛑 SLOT REMOVED:", slotStart, "→", slotEnd)
                continue
            }

            print("✅ SLOT KEPT:", slotStart, "→", slotEnd)

            let slotId = ISO8601DateFormatter().string(from: slotStart)
            let ref = slotCollection.document(slotId)

            writeBatch.setData([
                "startTime": Timestamp(date: slotStart),
                "endTime": Timestamp(date: slotEnd),
                "date": Timestamp(date: date),
                "isBooked": false,
                "bookingId": NSNull(),
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: ref)

            writeCount += 1

            if writeCount == 450 {
                try await writeBatch.commit()
                writeBatch = db.batch()
                writeCount = 0
            }
        }

        if writeCount > 0 {
            try await writeBatch.commit()
        }

        print("🎯 Slot regeneration complete")
    }
}
