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

            Text("\(booking.startDate.formatted(date: .omitted, time: .shortened)) - \(booking.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.secondary)

            if !booking.safeCustomerAddress.isEmpty {
                Text(booking.safeCustomerAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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

    // MARK: - Price

    private var formattedPrice: String {
        let pounds = Double(booking.price) / 100.0
        return String(format: "£%.2f", pounds)
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

        if isCancelled { return "Cancelled" }
        if booking.status == .refunded { return "Refunded" }
        if booking.endDate < Date() { return "Completed" }
        if isInProgress { return "In progress" }
        if booking.status == .pending_payment { return "Pending" }

        return "Confirmed"
    }

    private var statusColor: Color {

        if isCancelled { return AppColors.error }
        if booking.status == .refunded { return .gray }
        if booking.endDate < Date() { return .green }
        if isInProgress { return .orange }
        if booking.status == .pending_payment { return AppColors.primary }

        return AppColors.success
    }

    private var isCancelled: Bool {
        booking.status == .cancelled_by_business || booking.status == .cancelled_by_customer
    }

    private var isInProgress: Bool {
        booking.startDate <= Date() && booking.endDate >= Date()
    }

    // MARK: - Date

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
