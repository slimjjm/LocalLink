import SwiftUI

struct AddressCaptureView: View {

    let businessId: String
    let service: BusinessService

    @AppStorage("lastUsedAddress") private var storedAddress: String = ""
    @State private var addressLine: String = ""

    var body: some View {

        VStack(spacing: 24) {

            Text("Where should we come?")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)

            Text("Enter your address or postcode.")
                .foregroundColor(.secondary)

            TextField("Enter postcode or road name", text: $addressLine)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.primary.opacity(0.25))
                )
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            NavigationLink {

                BookingDateSelectorView(
                    businessId: businessId,
                    service: service,
                    customerAddress: addressLine
                )

            } label: {

                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .primaryButton()
            .disabled(addressLine.isEmpty)

            Spacer()
        }
        .padding()
        .background(AppColors.background)
        .navigationTitle("Your address")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            if addressLine.isEmpty {
                addressLine = storedAddress
            }
        }
        .onDisappear {

            storedAddress = addressLine
        }
    }
}
