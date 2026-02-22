import SwiftUI

struct BusinessCapacityTileView: View {

    @ObservedObject var viewModel: BusinessBookingsViewModel

    private var percent: Int {
        Int(viewModel.percentMonthFilled.rounded())
    }

    private var maxPossibleGBP: String {
        String(format: "£%.0f", Double(viewModel.maxPossibleThisMonth) / 100)
    }

    private var remainingGBP: String {
        let remaining = viewModel.maxPossibleThisMonth - viewModel.monthlyRevenueEarned
        return String(format: "£%.0f", Double(max(0, remaining)) / 100)
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("% Month Filled")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(percent)%")
                        .font(.title.bold())
                }

                Spacer()

                ProgressView(value: viewModel.percentMonthFilled, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
            }

            Divider()

            Text("Capacity Remaining")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(remainingGBP) of \(maxPossibleGBP) possible this month")
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
