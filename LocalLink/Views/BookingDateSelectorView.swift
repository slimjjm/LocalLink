import SwiftUI

struct BookingDateSelectorView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService

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
                    service: service,   // ✅ FIXED
                    date: selectedDate
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

