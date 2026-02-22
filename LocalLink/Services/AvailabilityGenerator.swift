import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class AvailabilityGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    private func log(_ message: String) {
        print("🟠 AvailabilityGenerator:", message)
    }

    // =================================================
    // MAIN ENTRY
    // =================================================
    func regenerateNextDays(
        businessId: String,
        staffId: String,
        numberOfDays: Int
    ) async throws {

        guard numberOfDays > 0 else { return }

        log("🚀 START regenerateNextDays")

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        // DELETE AVAILABILITY
        let availabilitySnap = try await staffRef
            .collection("availability")
            .getDocuments()

        try await deleteAsync(docs: availabilitySnap.documents)

        // DELETE SLOTS
        let slotSnap = try await staffRef
            .collection("availableSlots")
            .getDocuments()

        try await deleteAsync(docs: slotSnap.documents)

        // FETCH WEEKLY TEMPLATE ONCE
        let weekSnap = try await staffRef
            .collection("weeklyAvailability")
            .getDocuments()

        var weekly: [String: [String: Any]] = [:]
        weekSnap.documents.forEach {
            weekly[$0.documentID] = $0.data()
        }

        // FETCH BLOCKED TIMES ONCE
        let blockedSnapshot = try await db
            .collection("businesses")
            .document(businessId)
            .collection("blockedTimes")
            .getDocuments()

        let blockedTimes = blockedSnapshot.documents.compactMap {
            try? $0.data(as: BlockedTime.self)
        }

        let today = calendar.startOfDay(for: Date())
        guard let finalTargetDate = calendar.date(byAdding: .day, value: numberOfDays, to: today) else {
            return
        }

        // BATCH AVAILABILITY WRITES
        var batch = db.batch()
        var writeCount = 0

        for offset in 0..<numberOfDays {

            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

            let weekday = day.weekdayKey
            guard let config = weekly[weekday] else { continue }

            let closed = (config["closed"] as? Bool) ?? false
            if closed { continue }

            guard
                let open = config["open"] as? String,
                let close = config["close"] as? String,
                let startDate = makeDate(on: day, timeHHmm: open),
                let endDate = makeDate(on: day, timeHHmm: close),
                endDate > startDate
            else { continue }

            let ref = staffRef
                .collection("availability")
                .document(day.dateId())

            batch.setData([
                "date": Timestamp(date: day),
                "startTime": Timestamp(date: startDate),
                "endTime": Timestamp(date: endDate),
                "generatedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)

            writeCount += 1

            if writeCount == 450 {
                try await batch.commit()
                batch = db.batch()
                writeCount = 0
            }

            // SLOT GEN (already batched)
            try await SlotGenerator().generateSlotsForDay(
                businessId: businessId,
                staffId: staffId,
                date: day,
                startTime: startDate,
                endTime: endDate,
                blockedTimes: blockedTimes
            )
        }

        if writeCount > 0 {
            try await batch.commit()
        }

        // WRITE META ONCE
        try await staffRef
            .collection("meta")
            .document("availability")
            .setData([
                "generatedUntil": Timestamp(date: finalTargetDate),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

        log("🏁 Regen COMPLETE")
    }

    // =================================================
    // DELETE HELPER
    // =================================================
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

    // =================================================
    // TIME PARSE
    // =================================================
    private func makeDate(on day: Date, timeHHmm: String) -> Date? {

        let parts = timeHHmm.split(separator: ":")

        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1])
        else { return nil }

        return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }
}
