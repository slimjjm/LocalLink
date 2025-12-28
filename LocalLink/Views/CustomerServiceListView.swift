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
                    .padding()
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
                            businessId: businessId,   // 🔑 pass through unchanged
                            service: service
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.name)
                                .font(.headline)

                            if let details = service.details {
                                Text(details)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Services")
        .onAppear {
            print("📡 Loading services for businessId:", businessId)
            viewModel.loadServices(for: businessId, activeOnly: true)
        }
    }
}

