import SwiftUI

struct BusinessBookingRowView: View {

    let booking: Booking
    let onCancelled: () -> Void

    private let bookingService = BookingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(booking.serviceName)
                .font(.headline)

            Text("Staff: \(booking.staffName)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Customer: \(booking.customerId)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(booking.startDate, style: .time)
                .font(.caption)

            if booking.status == .confirmed {
                Button("Cancel", role: .destructive) {
                    cancelBooking()
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func cancelBooking() {
        guard let id = booking.id else { return }

        bookingService.cancelBookingAsBusiness(
            bookingId: id
        ) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    onCancelled()
                }
            }
        }
    }
}

