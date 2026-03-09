import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct SlotGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func generateSlotsForDay(
        businessId: String,
        staffId: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        intervalMinutes: Int = 30,
        // ✅ IMPORTANT: During regen, keep these false
        shouldClearExistingSlots: Bool = false,
        shouldCancelConflictingBookings: Bool = false
    ) async throws {

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        let slotCollection = staffRef.collection("availableSlots")

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // ===============================
        // DAY BLOCK CHECK (business-level collections with staffId field)
        // ===============================

        let dayBlockSnapshot = try await db
            .collection("businesses")
            .document(businessId)
            .collection("dayBlocks")
            .whereField("staffId", isEqualTo: staffId)
            .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .getDocuments()

        let hasDayBlock = !dayBlockSnapshot.documents.isEmpty

        // ===============================
        // TIME BLOCK FETCH
        // ===============================

        var timeBlocks: [TimeBlock] = []

        if !hasDayBlock {
            let snapshot = try await db
                .collection("businesses")
                .document(businessId)
                .collection("timeBlocks")
                .whereField("staffId", isEqualTo: staffId)
                .whereField("startDate", isLessThan: Timestamp(date: endOfDay))
                .whereField("endDate", isGreaterThan: Timestamp(date: startOfDay))
                .getDocuments()

            timeBlocks = snapshot.documents.compactMap {
                try? $0.data(as: TimeBlock.self)
            }
        }

        // ===============================
        // OPTIONAL: CANCEL BOOKINGS (heavy + not business-friendly)
        // ===============================

        if shouldCancelConflictingBookings {

            let bookingsSnapshot = try await db
                .collection("bookings")
                .whereField("businessId", isEqualTo: businessId)
                .whereField("staffId", isEqualTo: staffId)
                .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
                .whereField("startDate", isLessThan: Timestamp(date: endOfDay))
                .whereField("endDate", isGreaterThan: Timestamp(date: startOfDay))
                .getDocuments()

            for bookingDoc in bookingsSnapshot.documents {

                guard
                    let startTS = bookingDoc["startDate"] as? Timestamp,
                    let endTS = bookingDoc["endDate"] as? Timestamp
                else { continue }

                let bookingStart = startTS.dateValue()
                let bookingEnd = endTS.dateValue()

                let shouldCancel = hasDayBlock || timeBlocks.contains {
                    bookingStart < $0.endDate && bookingEnd > $0.startDate
                }

                if shouldCancel {
                    try await db
                        .collection("bookings")
                        .document(bookingDoc.documentID)
                        .updateData([
                            "status": BookingStatus.cancelledByBusiness.rawValue,
                            "cancelledAt": FieldValue.serverTimestamp()
                        ])
                }
            }
        }

        // ===============================
        // OPTIONAL: DELETE EXISTING SLOTS (only use outside full regen)
        // ===============================

        if shouldClearExistingSlots {

            let existingSlots = try await slotCollection
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("startTime", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()

            try await deleteAsync(docs: existingSlots.documents)
        }

        // If fully day-blocked: nothing to create
        if hasDayBlock { return }

        // ===============================
        // REBUILD SLOTS (BATCHED)
        // ===============================

        let slots = SlotBuilder.buildSlots(
            date: date,
            startTime: startTime,
            endTime: endTime,
            intervalMinutes: intervalMinutes
        )

        var batch = db.batch()
        var writeCount = 0

        for slotStart in slots {

            guard let slotEnd = calendar.date(byAdding: .minute, value: intervalMinutes, to: slotStart) else {
                continue
            }

            let overlaps = timeBlocks.contains {
                slotStart < $0.endDate && slotEnd > $0.startDate
            }
            if overlaps { continue }

            let slotId = Self.isoFormatter.string(from: slotStart)

            let ref = slotCollection.document(slotId)

            batch.setData([
                "businessId": businessId,
                "staffId": staffId,
                "startTime": Timestamp(date: slotStart),
                "endTime": Timestamp(date: slotEnd),
                "isBooked": false
            ], forDocument: ref, merge: true)

            writeCount += 1

            if writeCount == 450 {
                try await batch.commit()
                batch = db.batch()
                writeCount = 0
            }
        }

        if writeCount > 0 {
            try await batch.commit()
        }
    }

    // ===============================
    // DELETE HELPER (batched)
    // ===============================

    private func deleteAsync(docs: [QueryDocumentSnapshot]) async throws {

        guard !docs.isEmpty else { return }

        let chunkSize = 450
        var index = 0

        while index < docs.count {

            let end = min(index + chunkSize, docs.count)
            let chunk = Array(docs[index..<end])

            let batch = db.batch()
            chunk.forEach { batch.deleteDocument($0.reference) }

            try await batch.commit()
            index = end
        }
    }
}
