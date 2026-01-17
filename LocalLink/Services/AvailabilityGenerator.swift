import Foundation
import FirebaseFirestore

final class AvailabilityGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    /// Generates availability docs for the next `numberOfDays` (append-only: won't overwrite existing docs).
    func generateNextDays(
        businessId: String,
        staffId: String,
        numberOfDays: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        staffRef.getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data() else {
                completion(.success(()))
                return
            }

            // Support BOTH possible field names (your codebase currently uses both patterns)
            // - weeklyAvailability (what this generator expects)
            // - availability (what HorizonService parseWeeklyTemplate expects)
            let weekly =
                (data["weeklyAvailability"] as? [String: Any]) ??
                (data["availability"] as? [String: Any])

            guard let weekly else {
                completion(.success(())) // nothing to generate
                return
            }

            Task {
                do {
                    let today = self.calendar.startOfDay(for: Date())

                    for offset in 0..<numberOfDays {
                        guard let day = self.calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                        let weekday = day.weekdayKey // e.g. "monday"
                        guard
                            let dayConfig = weekly[weekday] as? [String: Any],
                            let closed = dayConfig["closed"] as? Bool,
                            closed == false,
                            let open = dayConfig["open"] as? String,
                            let close = dayConfig["close"] as? String
                        else { continue }

                        guard
                            let startDate = self.makeDate(on: day, timeHHmm: open),
                            let endDate = self.makeDate(on: day, timeHHmm: close),
                            endDate > startDate
                        else { continue }

                        let docId = day.dateId()
                        let docRef = staffRef
                            .collection("availability")
                            .document(docId)

                        // Append-only: skip if already exists
                        let existing = try await docRef.getDocument()
                        if existing.exists { continue }

                        try await docRef.setData([
                            "date": Timestamp(date: self.calendar.startOfDay(for: day)),
                            "startTime": Timestamp(date: startDate),
                            "endTime": Timestamp(date: endDate),
                            "generatedAt": FieldValue.serverTimestamp()
                        ])
                    }

                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
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
