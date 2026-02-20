import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TimeSlotSelectorView: View {

    let businessId: String
    let service: BusinessService
    let date: Date
    let customerAddress: String?

    @EnvironmentObject private var nav: NavigationState

    @State private var slotToStaff: [Date: [Staff]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?
    @State private var hasAnyAvailability = false

    private let db = Firestore.firestore()

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
                            time: selectedSlot,
                            customerAddress: customerAddress
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
        .onAppear {
            loadAvailability()
        }
    }

    // MARK: - Load availability

    private func loadAvailability() {
        isLoading = true
        slotToStaff = [:]
        hasAnyAvailability = false

        fetchBookingsForDay { bookings in
            fetchBlockedTimesForDay { blocks in
                removeCollisionsAndLoad(
                    bookings: bookings,
                    blockedTimes: blocks
                )
            }
        }
    }

    // MARK: - Fetch bookings

    private func fetchBookingsForDay(
        completion: @escaping ([Booking]) -> Void
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

                let bookings = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                completion(bookings)
            }
    }

    // MARK: - Fetch blocked time (NO RANGE INDEX NEEDED)

    private func fetchBlockedTimesForDay(
        completion: @escaping ([BlockedTime]) -> Void
    ) {

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        db.collection("blockedTimes")
            .whereField("businessId", isEqualTo: businessId)
            .getDocuments { snapshot, _ in

                let allBlocks = snapshot?.documents.compactMap {
                    try? $0.data(as: BlockedTime.self)
                } ?? []

                let todaysBlocks = allBlocks.filter {
                    $0.startDate < endOfDay &&
                    $0.endDate > startOfDay
                }

                completion(todaysBlocks)
            }
    }

    // MARK: - Collision logic

    private func removeCollisionsAndLoad(
        bookings: [Booking],
        blockedTimes: [BlockedTime]
    ) {

        let docId = date.dateId()
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
                        else { return }

                        let start = startTimestamp.dateValue()
                        let end = endTimestamp.dateValue()

                        let slots = generateSlots(
                            start: start,
                            end: end,
                            duration: self.service.durationMinutes
                        )

                        let safeSlots = slots.filter { slot in

                            let slotEnd = slot.addingTimeInterval(
                                Double(self.service.durationMinutes * 60)
                            )

                            for booking in bookings {
                                let slotRange = slot..<slotEnd
                                let bookingRange = booking.startDate..<booking.endDate
                                if slotRange.overlaps(bookingRange) {
                                    return false
                                }
                            }

                            for block in blockedTimes {
                                let slotRange = slot..<slotEnd
                                let blockRange = block.startDate..<block.endDate
                                if slotRange.overlaps(blockRange) {
                                    return false
                                }
                            }

                            return true
                        }

                        DispatchQueue.main.async {
                            if !safeSlots.isEmpty {
                                self.hasAnyAvailability = true
                            }

                            for slot in safeSlots {
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

    // MARK: - Slot builder

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
