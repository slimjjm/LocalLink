import SwiftUI

struct BusinessListView: View {

    let town: String?
    let category: String?

    @StateObject private var viewModel = CustomerBusinessListViewModel()

    init(town: String? = nil, category: String? = nil) {
        self.town = town
        self.category = category
    }

    var body: some View {

        List {

            // MARK: - Header

            Section {

                VStack(alignment: .leading, spacing: 6) {

                    Text("Local businesses")
                        .font(.title3.bold())
                        .foregroundColor(AppColors.charcoal)

                    if let town, let category {

                        Text("\(category) • \(town)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    } else {

                        Text("Browse all businesses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: - Loading

            if viewModel.isLoading {

                Section {

                    HStack {
                        Spacer()
                        ProgressView("Loading businesses…")
                        Spacer()
                    }
                }
            }

            // MARK: - Error

            else if let error = viewModel.errorMessage {

                Section {

                    Text(error)
                        .foregroundColor(AppColors.error)
                }
            }

            // MARK: - Empty

            else if viewModel.businesses.isEmpty {

                Section {

                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different town or category.")
                    )
                }
            }

            // MARK: - Results

            else {

                Section {

                    ForEach(viewModel.businesses) { business in

                        if let id = business.id {

                            NavigationLink {

                                CustomerBusinessProfileView(
                                    businessId: id
                                )

                            } label: {

                                BusinessRowView(
                                    business: business
                                )
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Select a business")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            viewModel.loadBusinesses(
                town: town,
                category: category
            )
        }
    }
}
