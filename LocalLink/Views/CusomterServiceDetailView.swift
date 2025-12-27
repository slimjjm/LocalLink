import SwiftUI

struct CustomerServiceDetailView: View {

    let businessId: String
    let service: Service

    var body: some View {
        VStack(spacing: 24) {

            Text(service.name)
                .font(.largeTitle.bold())

            if let details = service.details {
                Text(details)
                    .foregroundColor(.secondary)
            }

            Text("£\(service.price, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            NavigationLink("Book this service") {
                BookingDateSelectorView(
                    businessId: businessId,
                    service: service
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}
