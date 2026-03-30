import SwiftUI

struct BusinessRowView: View {

    let business: Business
    let nextSlot: Date?

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(business.businessName)
                .font(.headline)
                .foregroundColor(AppColors.charcoal)

            Text("\(business.category) • \(business.town)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let nextSlot {

                Text(
                    nextSlot.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.caption)
                .foregroundColor(.secondary)

            } else {

                Text("No availability")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
