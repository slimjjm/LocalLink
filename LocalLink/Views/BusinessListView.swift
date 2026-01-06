import SwiftUI

struct BusinessListView: View {

    @StateObject private var viewModel = CustomerBusinessListViewModel()

    var body: some View {
        List {

            Section {
                Text("Local businesses")
                    .font(.headline)
            }

            if viewModel.isLoading {
                Section {
                    ProgressView("Loading businesses…")
                }
            }
            else if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            else if viewModel.businesses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No businesses yet",
                        systemImage: "building.2",
                        description: Text("Local businesses will appear here once they join.")
                    )
                }
            }
            else {
                Section {
                    ForEach(viewModel.businesses) { business in
                        if let id = business.id {
                            NavigationLink {
                                CustomerServiceListView(businessId: id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(business.businessName)
                                        .font(.headline)

                                    if let address = business.address {
                                        Text(address)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select a business")
        .onAppear {
            viewModel.loadBusinesses()
        }
    }
}
