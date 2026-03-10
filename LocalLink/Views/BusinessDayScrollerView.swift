import SwiftUI

struct BusinessDayScrollerView: View {

    let businessId: String
    @ObservedObject var viewModel: BusinessBookingsViewModel

    @State private var referenceToday = Date().localMidnight()
    @State private var selectedDay: Date = Date().localMidnight()

    private var dayLabel: String {

        if Calendar.current.isDate(selectedDay, inSameDayAs: referenceToday) {
            return "Today"
        }

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

    private var bookingSummary: String {

        let count = selectedDayBookings.count

        if count == 0 {
            return "No bookings today"
        }

        if count == 1 {
            return "1 booking today"
        }

        return "\(count) bookings today"
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            // Header

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

            // Summary line

            if !viewModel.isLoading {
                Text(bookingSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Content

            if viewModel.isLoading {

                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)

            } else if selectedDayBookings.isEmpty {

                EmptyView()

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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onAppear {

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
