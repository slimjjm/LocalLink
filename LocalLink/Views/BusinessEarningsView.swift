import SwiftUI

struct BusinessEarningsView: View {

    let businessId: String
    @StateObject private var viewModel = BusinessBookingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Button(action: {
                    viewModel.goToPreviousMonth()
                }) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(viewModel.selectedMonthLabel)
                    .font(.headline)

                Spacer()

                Button(action: {
                    viewModel.goToNextMonth()
                }) {
                    Image(systemName: "chevron.right")
                }
            }

            Divider()

            HStack {

                VStack(alignment: .leading) {
                    Text("Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("£\(Double(viewModel.monthlyRevenueEarned)/100, specifier: "%.2f")")
                        .font(.title2.bold())
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Projected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("£\(Double(viewModel.monthlyProjectedIncome)/100, specifier: "%.2f")")
                        .font(.title2.bold())
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Refunded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("£\(Double(viewModel.monthlyRefunds)/100, specifier: "%.2f")")
                        .font(.title2.bold())
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.monthlyCompletedCount)")
                        .font(.title2.bold())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            viewModel.loadBookings(for: businessId)
        }
    }
}

