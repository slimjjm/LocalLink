import SwiftUI

struct CustomerServiceListView: View {

    let businessId: String
    @StateObject private var viewModel = ServiceListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading services…")
            }
            else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            else if viewModel.services.isEmpty {
                ContentUnavailableView(
                    "No Services",
                    systemImage: "scissors",
                    description: Text("This business hasn’t added any services yet.")
                )
            }
            else {
                List(viewModel.services) { service in
                    NavigationLink {
                        CustomerServiceDetailView(
                            businessId: businessId,
                            service: service
                        )
                    } label: {
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .font(.headline)
                            Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Services")
        .onAppear {
            viewModel.loadServices(for: businessId, activeOnly: false) // ✅ IMPORTANT
        }
    }
}
