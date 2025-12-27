import SwiftUI

struct BookingSlotListView: View {

    let businessId: String
    let selectedDate: Date
    let serviceDurationMinutes: Int

    @State private var slots: [TimeSlot] = []
    @State private var isLoading = true

    private let slotService = SlotService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading available times…")
            } else if slots.isEmpty {
                ContentUnavailableView(
                    "No availability",
                    systemImage: "clock.badge.xmark",
                    description: Text("There are no available times on this day.")
                )
            } else {
                List(slots) { slot in
                    slotRow(slot)
                }
            }
        }
        .navigationTitle("Available Times")
        .onAppear {
            loadSlots()
        }
    }

    private func slotRow(_ slot: TimeSlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeRange(slot))
                .font(.headline)

            Text(slot.staffName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func timeRange(_ slot: TimeSlot) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: slot.start)) – \(formatter.string(from: slot.end))"
    }

    private func loadSlots() {
        isLoading = true

        slotService.loadSlots(
            businessId: businessId,
            selectedDate: selectedDate,
            serviceDurationMinutes: serviceDurationMinutes
        ) { result in
            self.slots = result
            self.isLoading = false
        }
    }
}
