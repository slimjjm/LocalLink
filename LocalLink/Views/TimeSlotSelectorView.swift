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

    private let db = Firestore.firestore()

    // MARK: - Body
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
                List {
                    ForEach(slotToStaff.keys.sorted(), id: \.self) { slot in
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
            }

            if let selectedSlot,
               let availableStaff = slotToStaff[selectedSlot],
               let assignedStaff = availableStaff.first {

                NavigationLink {
                    BookingSummaryView(
                        businessId: businessId,
                        service: service,
                        staff: assignedStaff,
                        date: date,
                        time: selectedSlot        // ✅ C13 correct
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAvailability()
        }
    }

    // MARK: - Availability Logic

    private func loadAvailability() {
        isLoading = true

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, _ in

                let staffList = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []

                buildSlots(for: staffList)
            }
    }

    private func buildSlots(for staffList: [Staff]) {

        let weekdayIndex = Calendar.current.component(.weekday, from: date)
        let weekdayName = Calendar.current.weekdaySymbols[weekdayIndex - 1].lowercased()

        let group = DispatchGroup()
        var tempSlots: [Date: [Staff]] = [:]

        for staff in staffList {
            guard let staffId = staff.id else { continue }
            group.enter()

            db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("availability")
                .document("weekly")
                .getDocument { snapshot, _ in

                    defer { group.leave() }

                    guard
                        let data = snapshot?.data(),
                        let day = data[weekdayName] as? [String: Any],
                        let open = day["open"] as? String,
                        let close = day["close"] as? String,
                        let closed = day["closed"] as? Bool,
                        closed == false
                    else {
                        return
                    }

                    let slots = generateSlots(
                        open: open,
                        close: close,
                        duration: service.durationMinutes
                    )

                    for slot in slots {
                        tempSlots[slot, default: []].append(staff)
                    }
                }
        }

        group.notify(queue: .main) {
            self.slotToStaff = tempSlots
            self.isLoading = false
        }
    }

    // MARK: - Slot Generation

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
