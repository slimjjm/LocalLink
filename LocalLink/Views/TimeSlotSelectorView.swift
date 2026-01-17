import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TimeSlotSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService
    let date: Date

    @EnvironmentObject private var nav: NavigationState

    // MARK: - State
    @State private var slotToStaff: [Date: [Staff]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?
    @State private var hasAnyAvailability = false
    @State private var bookedSlots: Set<Date> = []

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - View
    var body: some View {
        VStack(spacing: 16) {

            Text("Choose a time")
                .font(.largeTitle.bold())

            if isLoading {
                ProgressView("Loading availability…")
            }
            else if !hasAnyAvailability {
                ContentUnavailableView(
                    "No availability",
                    systemImage: "clock",
                    description: Text("This business isn’t available on the selected date.")
                )
            }
            else if slotToStaff.isEmpty {
                ContentUnavailableView(
                    "Fully booked",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No slots left on this date.")
                )
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
                    Text("Confirm \(selectedSlot.formatted(date: .omitted, time: .shortened))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadAvailability() }
    }

    // MARK: - Availability loading

    private func loadAvailability() {
        isLoading = true
        slotToStaff = [:]
        hasAnyAvailability = false
        bookedSlots = []

        fetchBookedSlots { booked in
            bookedSlots = booked
            loadDateAvailability()
        }
    }

    // MARK: - Date-based availability

    private func loadDateAvailability() {

        let docId = date.dateId()
        let group = DispatchGroup()

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in

                let staffList = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []

                guard !staffList.isEmpty else {
                    self.isLoading = false
                    return
                }

                for staff in staffList {
                    guard let staffId = staff.id else { continue }
                    group.enter()

                    let ref = self.db
                        .collection("businesses")
                        .document(self.businessId)
                        .collection("staff")
                        .document(staffId)
                        .collection("availability")
                        .document(docId)

                    ref.getDocument { snap, _ in
                        defer { group.leave() }

                        guard
                            let data = snap?.data(),
                            let startTimestamp = data["startTime"] as? Timestamp,
                            let endTimestamp = data["endTime"] as? Timestamp
                        else {
                            return
                        }

                        let start = startTimestamp.dateValue()
                        let end = endTimestamp.dateValue()

                        let slots = generateSlots(
                            start: start,
                            end: end,
                            duration: self.service.durationMinutes
                        )

                        let availableSlots = slots.filter { slot in
                            !self.bookedSlots.contains {
                                Calendar.current.isDate(
                                    slot,
                                    equalTo: $0,
                                    toGranularity: .minute
                                )
                            }
                        }

                        DispatchQueue.main.async {
                            if !availableSlots.isEmpty {
                                self.hasAnyAvailability = true
                            }

                            for slot in availableSlots {
                                self.slotToStaff[slot, default: []].append(staff)
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    self.isLoading = false
                }
            }
    }

    // MARK: - Bookings

    private func fetchBookedSlots(
        completion: @escaping (Set<Date>) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("startDate", isGreaterThanOrEqualTo: startOfDay)
            .whereField("startDate", isLessThan: endOfDay)
            .whereField("status", isEqualTo: "confirmed")
            .getDocuments { snapshot, _ in

                let booked = snapshot?.documents.compactMap {
                    ($0["startDate"] as? Timestamp)?.dateValue()
                } ?? []

                completion(Set(booked))
            }
    }

    // MARK: - Slot generation

    private func generateSlots(
        start: Date,
        end: Date,
        duration: Int
    ) -> [Date] {

        var slots: [Date] = []
        var current = start

        while current.addingTimeInterval(TimeInterval(duration * 60)) <= end {
            slots.append(current)
            current = current.addingTimeInterval(TimeInterval(duration * 60))
        }

        return slots
    }
}

