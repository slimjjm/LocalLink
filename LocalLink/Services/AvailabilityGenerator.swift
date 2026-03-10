import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class AvailabilityGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // =================================================
    // GENERATE AVAILABILITY FROM A SPECIFIC DATE
    // =================================================

    func regenerateDays(
        businessId: String,
        staffId: String,
        startDate: Date,
        numberOfDays: Int,
        intervalMinutes: Int = 30
    ) async throws {

        guard numberOfDays > 0 else { return }

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        let availabilityCollection = staffRef.collection("availability")
        let slotCollection = staffRef.collection("availableSlots")

        let weekSnap = try await staffRef
            .collection("weeklyAvailability")
            .getDocuments()

        var weekly: [String: [String: Any]] = [:]
        weekSnap.documents.forEach { weekly[$0.documentID] = $0.data() }

        let baseDay = calendar.startOfDay(for: startDate)

        var batch = db.batch()
        var writeCount = 0

        for offset in 0..<numberOfDays {

            guard let day = calendar.date(byAdding: .day, value: offset, to: baseDay) else { continue }

            let startOfDay = calendar.startOfDay(for: day)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let weekday = day.weekdayKey
            guard let config = weekly[weekday] else { continue }

            let closed = (config["closed"] as? Bool) ?? false
            if closed { continue }

            guard
                let open = config["open"] as? String,
                let close = config["close"] as? String,
                let startTime = makeDate(on: day, timeHHmm: open),
                let endTime = makeDate(on: day, timeHHmm: close),
                endTime > startTime
            else { continue }

            // ============================
            // STAFF DAY BLOCK
            // ============================

            let dayBlockSnap = try await staffRef
                .collection("dayBlocks")
                .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .getDocuments()

            if !dayBlockSnap.documents.isEmpty { continue }

            // ============================
            // STAFF TIME BLOCKS
            // ============================

            let timeBlockSnap = try await staffRef
                .collection("timeBlocks")
                .whereField("startDate", isLessThan: Timestamp(date: endOfDay))
                .whereField("endDate", isGreaterThan: Timestamp(date: startOfDay))
                .getDocuments()

            let timeBlocks = timeBlockSnap.documents.compactMap {
                try? $0.data(as: TimeBlock.self)
            }

            // ============================
            // AVAILABILITY DOC
            // ============================

            let availabilityRef = availabilityCollection.document(day.dateId())

            batch.setData([
                "date": Timestamp(date: day),
                "startTime": Timestamp(date: startTime),
                "endTime": Timestamp(date: endTime),
                "generatedAt": FieldValue.serverTimestamp()
            ], forDocument: availabilityRef, merge: true)

            writeCount += 1

            // ============================
            // BUILD SLOTS
            // ============================

            var slotStart = startTime

            while slotStart < endTime {

                guard let slotEnd = calendar.date(byAdding: .minute, value: intervalMinutes, to: slotStart) else { break }

                let overlaps = timeBlocks.contains {
                    slotStart < $0.endDate && slotEnd > $0.startDate
                }

                if !overlaps {

                    let slotId = SlotID.make(from: slotStart)

                    let slotRef = slotCollection.document(slotId)

                    batch.setData([
                        "businessId": businessId,
                        "staffId": staffId,
                        "startTime": Timestamp(date: slotStart),
                        "endTime": Timestamp(date: slotEnd),
                        "isBooked": false
                    ], forDocument: slotRef)

                    writeCount += 1
                }

                if writeCount >= 450 {
                    try await batch.commit()
                    batch = db.batch()
                    writeCount = 0
                }

                slotStart = slotEnd
            }
        }

        if writeCount > 0 {
            try await batch.commit()
        }
    }

    // =================================================
    // HELPER
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
