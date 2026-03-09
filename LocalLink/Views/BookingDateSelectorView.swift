import SwiftUI

struct BookingDateSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService
    let customerAddress: String?   // passed from AddressCaptureView (or nil)

    // MARK: - State
    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(spacing: 28) {

            Text("Choose a date")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)

            DatePicker(
                "Select appointment date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)

            NavigationLink {
                TimeSlotSelectorView(
                    businessId: businessId,
                    service: service,
                    date: selectedDate,
                    customerAddress: customerAddress   // 👈 pass forward
                )
            } label: {
                Text("Next")
            }
            .primaryButton()

            Spacer()
        }
        .padding()
        .background(AppColors.background)
        .navigationTitle("Date")
        .navigationBarTitleDisplayMode(.inline)
    }
}
