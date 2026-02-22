import SwiftUI

struct BusinessDayScrollerView: View {

    let businessId: String
    @ObservedObject var viewModel: BusinessBookingsViewModel

    // Freeze reference today once per view lifecycle
    @State private var referenceToday = Date().localMidnight()
    @State private var selectedDay: Date = Date().localMidnight()

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM"
        return f.string(from: selectedDay)
    }

    private var selectedDayBookings: [Booking] {
        viewModel.upcoming
            .filter {
                let day = $0.bookingDay ?? $0.startDate.localMidnight()
                return day == selectedDay
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header: left/right + date label
            HStack {
                Button {
                    moveDay(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }

                Spacer()

                Text(dayLabel)
                    .font(.headline)

                Spacer()

                Button {
                    moveDay(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                }
            }

            // Content
            if viewModel.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if selectedDayBookings.isEmpty {
                Text("No jobs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedDayBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .onAppear {
            // keep selected day stable and aligned
            referenceToday = Date().localMidnight()
            selectedDay = referenceToday
        }
    }

    private func moveDay(_ delta: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) {
            selectedDay = newDay.localMidnight()
        }
    }
}
