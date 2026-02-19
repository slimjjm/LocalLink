import SwiftUI

struct BusinessBookingRowView: View {

    let booking: Booking
    var onCancelled: () -> Void

    @State private var isCancelling = false
    private let bookingService = BookingService()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            VStack {
                Text(timeString)
                    .font(.title3.bold())
                Spacer()
            }
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {

                Text(booking.serviceName)
                    .font(.headline)

                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                    Text(booking.customerName)
                }
                .font(.subheadline)

                if !booking.customerAddress.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)
                        Text(booking.customerAddress)
                            .lineLimit(2)
                    }
                    .font(.subheadline)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                    Text("Staff: \(booking.staffName)")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Divider()

                Button(role: .destructive) {
                    cancelBooking()
                } label: {
                    if isCancelling {
                        ProgressView()
                    } else {
                        Text("Cancel booking")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.vertical, 6)
    }

    private var timeString: String {
        booking.startDate.formatted(date: .omitted, time: .shortened)
    }

    private func cancelBooking() {
        guard let bookingId = booking.id else { return }

        isCancelling = true

        bookingService.cancelBookingAsBusiness(
            bookingId: bookingId
        ) { result in
            DispatchQueue.main.async {
                isCancelling = false
                if case .success = result {
                    onCancelled()
                }
            }
        }
    }
}

