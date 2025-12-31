import SwiftUI

struct BookingDetailView: View {

    let booking: Booking

    @Environment(\.dismiss) private var dismiss
    private let bookingService = BookingService()

    var body: some View {
        VStack(spacing: 16) {

            Text(booking.serviceName)
                .font(.largeTitle.bold())

            VStack(spacing: 6) {
                Text("Staff: \(booking.staffName)")
                Text(booking.startDate, style: .date)
                Text(booking.startDate, style: .time)
            }
            .foregroundColor(.secondary)

            Spacer()

            if booking.status == .confirmed {
                Button("Cancel booking", role: .destructive) {
                    cancelBooking()
                }
            }
        }
        .padding()
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func cancelBooking() {
        guard let id = booking.id else { return }

        bookingService.cancelBookingAsCustomer(
            bookingId: id
        ) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    dismiss()
                }
            }
        }
    }
}

