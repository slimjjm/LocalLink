import SwiftUI

struct BookingDateSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService
    let customerAddress: String?   // passed from AddressCaptureView (or nil)

    // MARK: - State
    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(spacing: 24) {

            Text("Choose a date")
                .font(.largeTitle.bold())

            DatePicker(
                "Select a date",
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
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Date")
        .navigationBarTitleDisplayMode(.inline)
    }
}
