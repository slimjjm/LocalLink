import SwiftUI
import FirebaseFirestore

struct CustomerServiceDetailView: View {

    let businessId: String
    let service: BusinessService

    @State private var serviceArea: String = ""

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 24) {

            Text(service.name)
                .font(.largeTitle.bold())

            if !serviceArea.isEmpty {
                Label(serviceArea, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let details = service.details {
                Text(details)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("£\(service.price, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            NavigationLink("Check availability") {
                nextStepView()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadBusiness)
    }

    // MARK: - Routing Logic

    @ViewBuilder
    private func nextStepView() -> some View {
        if service.locationType == "mobile" {
            AddressCaptureView(
                businessId: businessId,
                service: service
            )
        } else {
            BookingDateSelectorView(
                businessId: businessId,
                service: service,
                customerAddress: nil
            )
        }
    }

    // MARK: - Load Business Info

    private func loadBusiness() {
        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.serviceArea =
                        snapshot?.data()?["serviceArea"] as? String ?? ""
                }
            }
    }
}

