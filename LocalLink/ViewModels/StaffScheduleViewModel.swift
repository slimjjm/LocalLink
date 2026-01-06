import Foundation
import FirebaseFirestore

// MARK: - Models

struct StaffDaySchedule: Identifiable {
    let id: String
    let staffName: String
    let workingHours: String?
    let blocks: [ScheduleBlock]
}

struct ScheduleBlock: Identifiable {
    enum BlockType {
        case booked
        case free
    }

    let id = UUID()
    let start: Date
    let end: Date
    let title: String
    let type: BlockType

    var timeLabel: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}

// MARK: - ViewModel

@MainActor
final class StaffScheduleViewModel: ObservableObject {

    @Published var selectedDate: Date = Date()
    @Published var isLoading = true
    @Published var errorMessage = ""
    @Published var staffSchedules: [StaffDaySchedule] = []

    private let db = Firestore.firestore()

    func load(businessId: String) {
        isLoading = true
        errorMessage = ""
        staffSchedules = []

        loadStaff(businessId: businessId)
    }

    // MARK: - Load staff

    private func loadStaff(businessId: String) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.fail(error)
                    return
                }

                let staffDocs = snapshot?.documents ?? []
                if staffDocs.isEmpty {
                    self.isLoading = false
                    return
                }

                Task {
                    var schedules: [StaffDaySchedule] = []

                    for staff in staffDocs {
                        let staffId = staff.documentID
                        let name = staff.data()["name"] as? String ?? "Staff"

                        guard let availability = self.weeklyAvailability(
                            from: staff.data()
                        ) else {
                            continue
                        }

                        let bookings = await self.loadBookings(
                            businessId: businessId,
                            staffId: staffId
                        )

                        let blocks = self.buildBlocks(
                            availability: availability,
                            bookings: bookings
                        )

                        schedules.append(
                            StaffDaySchedule(
                                id: staffId,
                                staffName: name,
                                workingHours: availability.label,
                                blocks: blocks
                            )
                        )
                    }

                    self.staffSchedules = schedules
                    self.isLoading = false
                }
            }
    }

    // MARK: - Weekly availability (v1 source of truth)

    private func weeklyAvailability(
        from staffData: [String: Any]
    ) -> (start: Date, end: Date, label: String)? {

        guard
            let availability = staffData["availability"] as? [String: Any]
        else { return nil }

        let weekdayKey = weekdayString(from: selectedDate)

        guard
            let day = availability[weekdayKey] as? [String: Any],
            let closed = day["closed"] as? Bool,
            closed == false,
            let open = day["open"] as? String,
            let close = day["close"] as? String
        else {
            return nil
        }

        let start = combine(date: selectedDate, time: open)
        let end = combine(date: selectedDate, time: close)

        return (start, end, "\(open) – \(close)")
    }

    // MARK: - Bookings

    private func loadBookings(
        businessId: String,
        staffId: String
    ) async -> [(start: Date, end: Date, title: String)] {

        let dayStart = Calendar.current.startOfDay(for: selectedDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let snap = try? await db
            .collection("businesses")
            .document(businessId)
            .collection("bookings")
            .whereField("staffId", isEqualTo: staffId)
            .whereField("date", isGreaterThanOrEqualTo: dayStart)
            .whereField("date", isLessThan: dayEnd)
            .getDocuments()

        return (snap?.documents ?? []).compactMap { d in
            guard
                let startTS = d.data()["date"] as? Timestamp,
                let duration = d.data()["durationMinutes"] as? Int,
                let serviceName = d.data()["serviceName"] as? String
            else { return nil }

            let start = startTS.dateValue()
            let end = Calendar.current.date(
                byAdding: .minute,
                value: duration,
                to: start
            ) ?? start

            return (start, end, serviceName)
        }
        .sorted { $0.start < $1.start }
    }

    // MARK: - Build blocks (booked + free gaps)

    private func buildBlocks(
        availability: (start: Date, end: Date, label: String),
        bookings: [(start: Date, end: Date, title: String)]
    ) -> [ScheduleBlock] {

        var blocks: [ScheduleBlock] = []
        var cursor = availability.start

        for booking in bookings {

            if booking.start > cursor {
                blocks.append(
                    ScheduleBlock(
                        start: cursor,
                        end: booking.start,
                        title: "Free",
                        type: .free
                    )
                )
            }

            blocks.append(
                ScheduleBlock(
                    start: booking.start,
                    end: booking.end,
                    title: booking.title,
                    type: .booked
                )
            )

            cursor = booking.end
        }

        if cursor < availability.end {
            blocks.append(
                ScheduleBlock(
                    start: cursor,
                    end: availability.end,
                    title: "Free",
                    type: .free
                )
            )
        }

        return blocks
    }

    // MARK: - Helpers

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

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

