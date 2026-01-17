import FirebaseFirestore

final class StaffScheduleRepository {

    private let db = Firestore.firestore()

    func fetchWeeklyAvailability(
        businessId: String,
        staffId: String,
        date: Date,
        completion: @escaping ((start: Date, end: Date, label: String)?) -> Void
    ) {
        let weekdayKey = weekdayString(from: date)

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("weeklyAvailability")
            .document(weekdayKey)
            .getDocument { snapshot, _ in

                guard
                    let data = snapshot?.data(),
                    let enabled = data["enabled"] as? Bool,
                    enabled == true,
                    let startStr = data["start"] as? String,
                    let endStr = data["end"] as? String
                else {
                    completion(nil)
                    return
                }

                let start = combine(date: date, time: startStr)
                let end = combine(date: date, time: endStr)

                completion((start, end, "\(startStr) – \(endStr)"))
            }
    }
}

// MARK: - Helpers (keep local)

private func weekdayString(from date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_GB")
    f.dateFormat = "EEEE"
    return f.string(from: date).lowercased()
}

private func combine(date: Date, time: String) -> Date {
    let parts = time.split(separator: ":")
    let hour = Int(parts.first ?? "0") ?? 0
    let minute = Int(parts.last ?? "0") ?? 0

    return Calendar.current.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: date
    ) ?? date
}
