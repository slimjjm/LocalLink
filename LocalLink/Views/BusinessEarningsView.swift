import SwiftUI

struct BusinessEarningsView: View {
    
    let businessId: String
    @ObservedObject var viewModel: BusinessBookingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack {
                Button {
                    viewModel.goToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(viewModel.selectedMonthLabel)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    viewModel.goToNextMonth()
                } label: {
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
                    Text("Booked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("£\(Double(viewModel.monthlyProjectedIncome)/100, specifier: "%.2f")")
                        .font(.title2.bold())
                }
            }
        }
    }
}
