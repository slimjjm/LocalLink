import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TimeSlotSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService
    let date: Date

    // MARK: - Environment
    @EnvironmentObject private var nav: NavigationState

    // MARK: - State
    @State private var slotToStaff: [Date: [Staff]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?
    @State private var hasAnyAvailability = false

    // MARK: - Services
    private let db = Firestore.firestore()
    private let staffRepo = StaffAvailabilityRepository()

    // MARK: - View
    var body: some View {
        VStack(spacing: 16) {

            Text("Choose a time")
                .font(.largeTitle.bold())

            if isLoading {
                ProgressView("Loading availability…")
            }

            // ❌ Business closed / no staff working
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

            // ✅ Confirm CTA
            if let selectedSlot,
               let staff = slotToStaff[selectedSlot]?.first,
               let serviceId = service.id,
               let staffId = staff.id {

                Button {
                    nav.path.append(
                        AppRoute.bookingSummary(
                            businessId: businessId,
                            serviceId: serviceId,
                            staffId: staffId,
                            date: date,
                            time: selectedSlot
                        )
                    )
                } label: {
                    Text(
                        "Confirm \(selectedSlot.formatted(date: .omitted, time: .shortened))"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }


            Spacer()
        }
        .padding()
        .navigationTitle("Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAvailability()
        }
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

                        guard
                            let day = availability[dayKey],
                            !day.closed
                        else {
                            group.leave()
                            return
                        }

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
        let formatter = DateFormatter()
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

