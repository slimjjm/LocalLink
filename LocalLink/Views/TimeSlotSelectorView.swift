import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TimeSlotSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: Service
    let date: Date

    // MARK: - State
    @State private var slotToStaff: [Date: [Staff]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?

    // 🔍 Debug
    @State private var debugStatus: String = "Starting…"

    // MARK: - Repositories
    private let hoursRepo = BusinessHoursRepository()
    private let staffRepo = StaffAvailabilityRepository()
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 16) {

            Text("Choose a time")
                .font(.largeTitle.bold())

            if isLoading {
                ProgressView("Loading availability…")
            }
            else if slotToStaff.isEmpty {
                Text("No availability on this date")
                    .foregroundColor(.secondary)
            }
            else {
                List(slotToStaff.keys.sorted(), id: \.self) { slot in
                    Button {
                        selectedSlot = slot
                    } label: {
                        HStack {
                            Text(slot.formatted(date: .omitted, time: .shortened))
                            Spacer()
                            Text("\(slotToStaff[slot]?.count ?? 0) available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if let selectedSlot,
               let staff = slotToStaff[selectedSlot]?.first {

                NavigationLink {
                    BookingSummaryView(
                        businessId: businessId,
                        service: service,
                        staff: staff,
                        date: date,
                        time: selectedSlot
                    )
                } label: {
                    Text("Confirm \(selectedSlot.formatted(date: .omitted, time: .shortened))")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            Text(debugStatus)
                .font(.caption.monospaced())
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
        }
        .padding()
        .navigationTitle("Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAvailability()
        }
    }

    // MARK: - Core D4 Logic

    private func loadAvailability() {
        isLoading = true
        slotToStaff = [:]
        debugStatus = "Loading started"

        let dayKey = weekdayKey(from: date)

        hoursRepo.fetchHours(businessId: businessId) { hours in
            guard
                let todayHours = hours[dayKey],
                todayHours.isOpen,
                let open = todayHours.open,
                let close = todayHours.close
            else {
                debugStatus = "⛔ Business closed"
                finish()
                return
            }

            db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .whereField("isActive", isEqualTo: true)
                .getDocuments { snapshot, _ in

                    guard let docs = snapshot?.documents else {
                        debugStatus = "❌ No staff"
                        finish()
                        return
                    }

                    let staffList = docs.compactMap {
                        try? $0.data(as: Staff.self)
                    }

                    let group = DispatchGroup()

                    for staff in staffList {
                        guard let staffId = staff.id else { continue }

                        group.enter()

                        staffRepo.fetchAvailability(
                            businessId: businessId,
                            staffId: staffId
                        ) { availability in

                            guard
                                let staffDay = availability[dayKey],
                                staffDay.closed == false,
                                let staffOpen = staffDay.start,
                                let staffClose = staffDay.end
                            else {
                                group.leave()
                                return
                            }

                            let start = max(open, staffOpen)
                            let end   = min(close, staffClose)

                            let slots = generateSlots(
                                open: start,
                                close: end,
                                duration: service.durationMinutes
                            )

                            self.fetchBookings(
                                staffId: staffId,
                                completion: { bookings in

                                    let availableSlots = slots.filter { slot in
                                        let slotEnd = slot.addingTimeInterval(
                                            TimeInterval(service.durationMinutes * 60)
                                        )

                                        return !bookings.contains {
                                            overlaps(
                                                slotStart: slot,
                                                slotEnd: slotEnd,
                                                booking: $0
                                            )
                                        }
                                    }

                                    DispatchQueue.main.async {
                                        for slot in availableSlots {
                                            slotToStaff[slot, default: []].append(staff)
                                        }
                                    }

                                    group.leave()
                                }
                            )
                        }
                    }

                    group.notify(queue: .main) {
                        debugStatus = "✅ Availability loaded"
                        finish()
                    }
                }
        }
    }

    // MARK: - Booking Blocking

    private func fetchBookings(
        staffId: String,
        completion: @escaping ([Booking]) -> Void
    ) {
        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .getDocuments { snapshot, _ in

                let allBookings = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                let calendar = Calendar.current

                let sameDayBookings = allBookings.filter {
                    calendar.isDate($0.startDate, inSameDayAs: date)
                }

                completion(sameDayBookings)
            }
    }


    private func overlaps(
        slotStart: Date,
        slotEnd: Date,
        booking: Booking
    ) -> Bool {
        slotStart < booking.endDate && slotEnd > booking.startDate
    }

    private func finish() {
        DispatchQueue.main.async {
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func weekdayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).lowercased()
    }

    private func generateSlots(
        open: String,
        close: String,
        duration: Int
    ) -> [Date] {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard
            let openTime = formatter.date(from: open),
            let closeTime = formatter.date(from: close)
        else { return [] }

        var slots: [Date] = []

        var current = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: openTime),
            minute: Calendar.current.component(.minute, from: openTime),
            second: 0,
            of: date
        )!

        let end = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: closeTime),
            minute: Calendar.current.component(.minute, from: closeTime),
            second: 0,
            of: date
        )!

        while current.addingTimeInterval(TimeInterval(duration * 60)) <= end {
            slots.append(current)
            current = current.addingTimeInterval(TimeInterval(duration * 60))
        }

        return slots
    }
}

