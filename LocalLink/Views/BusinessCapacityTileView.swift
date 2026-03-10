import SwiftUI

struct BusinessCapacityTileView: View {

    @ObservedObject var viewModel: BusinessBookingsViewModel

    // % of slots already booked
    private var percentFilled: Int {
        Int(viewModel.percentMonthFilled.rounded())
    }

    // remaining availability
    private var remainingPercent: Int {
        max(0, 100 - percentFilled)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text("Calendar Fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(percentFilled)%")
                        .font(.title.bold())
                }

                Spacer()
            }

            ProgressView(value: viewModel.percentMonthFilled, total: 100)
                .tint(AppColors.primary)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            Divider()

            VStack(alignment: .leading, spacing: 4) {

                Text("Availability")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(remainingPercent)% of booking slots still available this month")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
