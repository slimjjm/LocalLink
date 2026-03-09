import SwiftUI
import FirebaseAuth

struct BusinessBookingRowView: View {

    let booking: Booking
    var onCancelled: () -> Void

    @State private var isCancelling = false

    private let bookingService = BookingService()

    var body: some View {

        ZStack(alignment: .topTrailing) {

            HStack(alignment: .top, spacing: 14) {

                VStack {
                    Text(timeString)
                        .font(.title3.bold())

                    Spacer()
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 10) {

                    Text(booking.safeServiceName)
                        .font(.headline)
                        .foregroundColor(AppColors.charcoal)

                    HStack(spacing: 6) {

                        Image(systemName: "person.fill")

                        Text(booking.safeCustomerName)
                    }
                    .font(.subheadline)

                    if !booking.safeCustomerAddress.isEmpty {

                        HStack(spacing: 6) {

                            Image(systemName: "mappin.and.ellipse")

                            Text(booking.safeCustomerAddress)
                                .lineLimit(2)
                        }
                        .font(.subheadline)
                    }

                    HStack(spacing: 6) {

                        Image(systemName: "person.2.fill")

                        Text("Staff: \(booking.safeStaffName)")
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
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(.vertical, 6)

            if booking.unreadBusinessCount > 0 {

                Text("\(booking.unreadBusinessCount)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(6)
                    .background(AppColors.primary)
                    .clipShape(Circle())
                    .offset(x: -6, y: 6)
            }
        }
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
