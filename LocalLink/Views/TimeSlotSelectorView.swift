import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TimeSlotSelectorView: View {

    let businessId: String
    let service: BusinessService
    let date: Date

    @State private var slotToStaff: [Date: [Staff]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?
    @State private var hasAnyAvailability = false   // 👈 NEW

    private let db = Firestore.firestore()
    private let staffRepo = StaffAvailabilityRepository()

    var body: some View {
        VStack(spacing: 16) {

            Text("Choose a time")
                .font(.largeTitle.bold())

            if isLoading {
                ProgressView("Loading availability…")
            }

            // ❌ Closed / no staff
            else if !hasAnyAvailability {
                ContentUnavailableView(
                    "No availability",
                    systemImage: "clock",
                    description: Text("This business isn’t available on the selected date.")
                )
            }

            // ❌ Fully booked
            else if slotToStaff.isEmpty {
                ContentUnavailableView(
                    "Fully booked",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No slots left on this date. Please choose another day.")
                )
            }

            // ✅ Slots available
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

            // Confirm CTA
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
        }
        .padding()
        .navigationTitle("Time")
        .onAppear(perform: loadAvailability)
    }

    // MARK: - Load availability

    private func loadAvailability() {
        isLoading = true
        slotToStaff = [:]
        hasAnyAvailability = false

        let dayKey = weekdayKey(from: date)
        let group = DispatchGroup()

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, _ in

                let staffList = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []

                for staff in staffList {
                    guard let staffId = staff.id else { continue }
                    group.enter()

                    staffRepo.fetchAvailability(
                        businessId: businessId,
                        staffId: staffId
                    ) { availability in

                        guard let day = availability[dayKey], !day.closed else {
                            group.leave()
                            return
                        }

                        // 👇 At least one staff member is working
                        DispatchQueue.main.async {
                            hasAnyAvailability = true
                        }

                        let slots = generateSlots(
                            open: day.open,
                            close: day.close,
                            duration: service.durationMinutes
                        )

                        DispatchQueue.main.async {
                            for slot in slots {
                                slotToStaff[slot, default: []].append(staff)
                            }
                        }

                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    isLoading = false
                }
            }
    }

    // MARK: - Helpers

    private func weekdayKey(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date).lowercased()
    }

    private func generateSlots(open: String, close: String, duration: Int) -> [Date] {
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

