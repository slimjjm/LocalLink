import SwiftUI

struct AddressCaptureView: View {

    let businessId: String
    let service: BusinessService

    @AppStorage("lastUsedAddress") private var storedAddress: String = ""
    @State private var addressLine: String = ""

    var body: some View {
        VStack(spacing: 20) {

            Text("Where should we come?")
                .font(.title.bold())

            TextField("Enter postcode or road name", text: $addressLine)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            NavigationLink("Continue") {
                BookingDateSelectorView(
                    businessId: businessId,
                    service: service,
                    customerAddress: addressLine
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(addressLine.isEmpty)

            Spacer()
        }
        .padding()
        .navigationTitle("Your address")
        .onAppear {
            // Autofill previous address
            if addressLine.isEmpty {
                addressLine = storedAddress
            }
        }
        .onDisappear {
            // Save for next time
            storedAddress = addressLine
        }
    }
}

