import SwiftUI

struct CustomerServiceListView: View {

    let businessId: String
    @StateObject private var viewModel = ServiceListViewModel()

    var body: some View {
        Group {

            // Loading
            if viewModel.isLoading {
                ProgressView("Loading services…")
            }

            // Error
            else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            // Empty state
            else if viewModel.services.isEmpty {
                ContentUnavailableView(
                    "No services yet",
                    systemImage: "scissors",
                    description: Text("This business hasn’t added any services yet.")
                )
            }

            // Services list
            else {
                List(viewModel.services) { service in
                    NavigationLink {
                        CustomerServiceDetailView(
                            businessId: businessId,
                            service: service
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name)
                                .font(.headline)

                            Text(
                                "£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Services")
        .onAppear {
            viewModel.loadServices(
                for: businessId,
                activeOnly: false
            )
        }
    }
}
