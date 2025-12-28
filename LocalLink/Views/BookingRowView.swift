import SwiftUI

struct BookingRowView: View {

    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(booking.serviceName)
                .font(.headline)

            Text(booking.staffName)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(booking.startDate, style: .date)
                .font(.caption)
        }
    }
}
