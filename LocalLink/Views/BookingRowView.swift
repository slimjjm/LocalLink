import SwiftUI

struct BookingRowView: View {

    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(booking.serviceName)
                    .font(.headline)

                Spacer()

                statusBadge
            }

            Text(booking.staffName)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formattedDate)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch booking.status {
        case .confirmed:
            return "Confirmed"
        case .completed:
            return "Completed"
        case .refunded:
            return "Refunded"
        case .cancelledByBusiness:
            return "Cancelled"
        case .cancelledByCustomer:
            return "Cancelled"
        case .pendingPayment:
            return "Pending"
        }
    }


    private var statusColor: Color {
        switch booking.status {
        case .confirmed:
            return .green
        case .completed:
            return .blue
        case .refunded:
            return .gray
        case .cancelledByBusiness:
            return .red
        case .cancelledByCustomer:
            return .red
        case .pendingPayment:
            return .orange
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: booking.startDate)
    }
}
