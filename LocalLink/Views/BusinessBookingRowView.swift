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

                // ⏰ TIME BLOCK
                VStack(alignment: .leading, spacing: 4) {
                    
                    Text(startTimeString)
                        .font(.title3.bold())
                    
                    Text(endTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70, alignment: .leading)

                // 📋 DETAILS
                VStack(alignment: .leading, spacing: 10) {

                    // SERVICE
                    Text(booking.safeServiceName)
                        .font(.headline)
                        .foregroundColor(AppColors.charcoal)

                    // 📅 FULL DATE (NEW)
                    Text(fullDateString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 👤 CUSTOMER
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                        Text(booking.safeCustomerName)
                    }
                    .font(.subheadline)

                    // 📍 ADDRESS
                    if !booking.safeCustomerAddress.isEmpty {

                        HStack(alignment: .top, spacing: 6) {

                            Image(systemName: "mappin.and.ellipse")

                            Text(booking.safeCustomerAddress)
                                .lineLimit(2)
                        }
                        .font(.subheadline)
                    }

                    // 👷 STAFF
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("Staff: \(booking.safeStaffName)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Divider()

                    // ❌ CANCEL BUTTON
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

            // 🔔 UNREAD BADGE
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

    // MARK: - Time Formatting

    private var startTimeString: String {
        booking.startDate.formatted(date: .omitted, time: .shortened)
    }

    private var endTimeString: String {
        booking.endDate.formatted(date: .omitted, time: .shortened)
    }

    private var fullDateString: String {
        booking.startDate.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Actions

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
