import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class AvailabilityHorizonService {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    func ensureHorizon(
        businessId: String,
        staffId: String,
        horizonDays: Int = 90
    ) async throws {

        guard horizonDays > 0 else { return }

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        let metaRef = staffRef.collection("meta").document("availability")
        let metaSnap = try await metaRef.getDocument()

        let today = calendar.startOfDay(for: Date())

        let generatedUntil =
            (metaSnap.data()?["generatedUntil"] as? Timestamp)?.dateValue()
            ?? today

        guard let target = calendar.date(byAdding: .day, value: horizonDays, to: today) else {
            return
        }

        if generatedUntil >= target { return }

        var day = calendar.startOfDay(for: max(generatedUntil, today))

        // Fetch weekly template once
        let weekSnap = try await staffRef.collection("weeklyAvailability").getDocuments()
        var weekly: [String: [String: Any]] = [:]
        weekSnap.documents.forEach { weekly[$0.documentID.lowercased()] = $0.data() }

        // Generate day-by-day
        while day < target {

            let weekdayKey = day.weekdayKey // ✅ your extension returns "monday"...

            guard
                let config = weekly[weekdayKey],
                (config["closed"] as? Bool) == false,
                let openStr = config["open"] as? String,
                let closeStr = config["close"] as? String,
                let startTime = makeDate(on: day, timeHHmm: openStr),
                let endTime = makeDate(on: day, timeHHmm: closeStr),
                endTime > startTime
            else {
                day = calendar.date(byAdding: .day, value: 1, to: day)!
                continue
            }

            // Write availability (single doc)
            let availRef = staffRef.collection("availability").document(day.dayId())
            try await availRef.setData([
                "date": Timestamp(date: day),
                "startTime": Timestamp(date: startTime),
                "endTime": Timestamp(date: endTime),
                "generatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            // Generate slots using YOUR generator (but optimized inside)
            try await SlotGenerator().generateSlotsForDay(
                businessId: businessId,
                staffId: staffId,
                date: day,
                startTime: startTime,
                endTime: endTime
            )

            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        try await metaRef.setData([
            "generatedUntil": Timestamp(date: target),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func makeDate(on day: Date, timeHHmm: String) -> Date? {
        guard TimeHHmm.isValid(timeHHmm) else { return nil }
        let parts = timeHHmm.split(separator: ":")
        let h = Int(parts[0])!
        let m = Int(parts[1])!
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }
}
