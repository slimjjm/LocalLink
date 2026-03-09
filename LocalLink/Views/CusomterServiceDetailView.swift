import SwiftUI
import FirebaseFirestore

struct CustomerServiceDetailView: View {

    let businessId: String
    let service: BusinessService

    @State private var serviceArea: String = ""

    private let db = Firestore.firestore()

    var body: some View {

        ScrollView {

            VStack(spacing: 28) {

                // MARK: Service Name

                VStack(spacing: 6) {

                    Text(service.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.charcoal)

                    if !serviceArea.isEmpty {

                        Label(serviceArea, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: Details

                if let details = service.details, !details.isEmpty {

                    Text(details)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // MARK: Price Card

                VStack(spacing: 6) {

                    Text("Price")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("£\(service.price, specifier: "%.2f")")
                        .font(.title.bold())
                        .foregroundColor(AppColors.charcoal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )

                Spacer(minLength: 10)

                // MARK: Continue Button

                NavigationLink {

                    nextStepView()

                } label: {

                    Text("Check availability")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
                .padding(.top, 8)
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadBusiness)
    }

    // MARK: Routing

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

    // MARK: Business Data

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
