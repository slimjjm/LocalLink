import SwiftUI

struct BookingRowView: View {

    let booking: Booking

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            HStack {

                Text(booking.safeServiceName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.charcoal)

                Spacer()

                statusBadge
            }

            Text(formattedDate)
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack {

                Text(booking.safeStaffName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formattedPrice)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var formattedPrice: String {

        let pounds = Double(booking.price) / 100.0
        return String(format: "£%.2f", pounds)
    }

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

        case .cancelledByBusiness, .cancelledByCustomer:
            return "Cancelled"

        case .pendingPayment:
            return "Pending"

        case .unknown:
            return "Processing"
        }
    }

    private var statusColor: Color {

        switch booking.status {

        case .confirmed:
            return AppColors.success

        case .completed:
            return AppColors.charcoal

        case .refunded:
            return .gray

        case .cancelledByBusiness, .cancelledByCustomer:
            return AppColors.error

        case .pendingPayment:
            return AppColors.primary

        case .unknown:
            return .gray.opacity(0.6)
        }
    }

    private static let formatter: DateFormatter = {

        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var formattedDate: String {
        Self.formatter.string(from: booking.startDate)
    }
}
