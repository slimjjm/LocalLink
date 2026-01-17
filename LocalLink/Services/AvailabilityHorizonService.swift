import Foundation
import FirebaseFirestore

final class AvailabilityHorizonService {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    /// Ensures availability exists for this staff member up to today + horizonDays.
    @discardableResult
    func ensureHorizon(
        businessId: String,
        staffId: String,
        horizonDays: Int = 14
    ) async -> Date {

        let today = calendar.startOfDay(for: Date())
        guard let targetEnd = calendar.date(byAdding: .day, value: horizonDays, to: today) else {
            return today
        }

        // Load weekly template from subcollection (SOURCE OF TRUTH)
        let weeklyTemplate = await loadWeeklyTemplate(
            businessId: businessId,
            staffId: staffId
        )

        if weeklyTemplate.isEmpty {
            return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        let latest = await fetchLatestGeneratedDate(
            businessId: businessId,
            staffId: staffId
        )

        let startFrom = max(
            calendar.date(byAdding: .day, value: 1, to: latest ?? today) ?? today,
            today
        )

        await generateMissingDays(
            businessId: businessId,
            staffId: staffId,
            weeklyTemplate: weeklyTemplate,
            startDate: startFrom,
            endDate: targetEnd
        )

        return await fetchLatestGeneratedDate(
            businessId: businessId,
            staffId: staffId
        ) ?? today
    }

    // MARK: - Weekly template

    private struct DayTemplate {
        let open: String
        let close: String
        let closed: Bool
    }

    private func loadWeeklyTemplate(
        businessId: String,
        staffId: String
    ) async -> [String: DayTemplate] {

        do {
            let snap = try await db
                .collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("weeklyAvailability")
                .getDocuments()

            var out: [String: DayTemplate] = [:]

            for doc in snap.documents {
                let data = doc.data()
                let open = data["open"] as? String ?? ""
                let close = data["close"] as? String ?? ""
                let closed = data["closed"] as? Bool ?? true

                out[doc.documentID.lowercased()] = DayTemplate(
                    open: open,
                    close: close,
                    closed: closed
                )
            }

            return out
        } catch {
            print("❌ loadWeeklyTemplate error:", error)
            return [:]
        }
    }

    // MARK: - Latest generated date

    private func fetchLatestGeneratedDate(
        businessId: String,
        staffId: String
    ) async -> Date? {

        do {
            let snap = try await db
                .collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("availability")
                .order(by: "date", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard
                let doc = snap.documents.first,
                let ts = doc.data()["date"] as? Timestamp
            else { return nil }

            return calendar.startOfDay(for: ts.dateValue())
        } catch {
            print("❌ fetchLatestGeneratedDate error:", error)
            return nil
        }
    }

    // MARK: - Generate (append-only)

    private func generateMissingDays(
        businessId: String,
        staffId: String,
        weeklyTemplate: [String: DayTemplate],
        startDate: Date,
        endDate: Date
    ) async {

        var cursor = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while cursor <= end {

            let key = cursor.weekdayKey

            if let template = weeklyTemplate[key],
               template.closed == false,
               !template.open.isEmpty,
               !template.close.isEmpty {

                guard
                    let startDT = makeDate(on: cursor, timeHHmm: template.open),
                    let endDT = makeDate(on: cursor, timeHHmm: template.close),
                    endDT > startDT
                else {
                    cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
                    continue
                }

                let ref = db
                    .collection("businesses")
                    .document(businessId)
                    .collection("staff")
                    .document(staffId)
                    .collection("availability")
                    .document(cursor.dateId())

                do {
                    let existing = try await ref.getDocument()
                    if !existing.exists {
                        try await ref.setData([
                            "date": Timestamp(date: cursor),
                            "startTime": Timestamp(date: startDT),
                            "endTime": Timestamp(date: endDT),
                            "generatedAt": FieldValue.serverTimestamp()
                        ])
                    }
                } catch {
                    print("❌ generateMissingDays error:", error)
                }
            }

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
    }

    // MARK: - Helpers

    private func makeDate(on day: Date, timeHHmm: String) -> Date? {
        let parts = timeHHmm.split(separator: ":")
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1])
        else { return nil }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

