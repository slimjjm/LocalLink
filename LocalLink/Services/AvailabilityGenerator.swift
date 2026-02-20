import Foundation
import FirebaseFirestore

final class AvailabilityGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    // MARK: - Public: Regenerate EVERYTHING clean
    func regenerateNextDays(
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

        let batch = db.batch()

        // 🔥 DELETE FUTURE AVAILABILITY
        staffRef.collection("availability")
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                snapshot?.documents.forEach {
                    batch.deleteDocument($0.reference)
                }

                // 🔥 DELETE OLD SLOTS
                staffRef.collection("availableSlots")
                    .getDocuments { slotsSnap, err in

                        if let err {
                            completion(.failure(err))
                            return
                        }

                        slotsSnap?.documents.forEach {
                            batch.deleteDocument($0.reference)
                        }

                        batch.commit { commitErr in
                            if let commitErr {
                                completion(.failure(commitErr))
                                return
                            }

                            // 🔁 REBUILD EVERYTHING
                            self.generateNextDays(
                                businessId: businessId,
                                staffId: staffId,
                                numberOfDays: numberOfDays,
                                completion: completion
                            )
                        }
                    }
            }
    }

    // MARK: - Generate from weekly template
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

            guard let data = snapshot?.data(),
                  let weekly = data["weeklyAvailability"] as? [String: Any]
            else {
                completion(.success(()))
                return
            }

            Task {
                do {
                    let today = self.calendar.startOfDay(for: Date())

                    for offset in 0..<numberOfDays {

                        guard let day = self.calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                        let weekday = day.weekdayKey

                        guard
                            let config = weekly[weekday] as? [String: Any],
                            let closed = config["closed"] as? Bool,
                            closed == false,
                            let open = config["open"] as? String,
                            let close = config["close"] as? String
                        else { continue }

                        guard
                            let startDate = self.makeDate(on: day, timeHHmm: open),
                            let endDate = self.makeDate(on: day, timeHHmm: close)
                        else { continue }

                        let docId = day.dateId()

                        // ✅ Save working window
                        try await staffRef
                            .collection("availability")
                            .document(docId)
                            .setData([
                                "date": Timestamp(date: day),
                                "startTime": Timestamp(date: startDate),
                                "endTime": Timestamp(date: endDate),
                                "generatedAt": FieldValue.serverTimestamp()
                            ])

                        // 🔥 Generate BOOKABLE SLOTS
                        await SlotGenerator().generateSlotsForDay(
                            businessId: businessId,
                            staffId: staffId,
                            date: day,
                            startTime: startDate,
                            endTime: endDate
                        )
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

        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1])
        else { return nil }

        return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
    }
}
