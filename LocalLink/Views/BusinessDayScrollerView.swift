import SwiftUI

struct BusinessDayScrollerView: View {

    let businessId: String
    @ObservedObject var viewModel: BusinessBookingsViewModel

    private var selectedDay: Date {
        viewModel.selectedDate
    }

    private var dayLabel: String {

        if Calendar.current.isDateInToday(selectedDay) {
            return "Today"
        }

        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM"
        return f.string(from: selectedDay)
    }

    private var bookings: [Booking] {
        viewModel.bookings(for: selectedDay)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Button {
                    moveDay(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(dayLabel)
                    .font(.headline)

                Spacer()

                Button {
                    moveDay(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            if viewModel.isLoading {

                ProgressView()

            } else if bookings.isEmpty {

                Text("No bookings")
                    .foregroundColor(.secondary)

            } else {

                VStack(spacing: 10) {

                    ForEach(bookings) { booking in

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
    }

    private func moveDay(_ delta: Int) {

        if let newDay = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) {
            viewModel.selectedDate = newDay.localMidnight()
        }
    }
}
