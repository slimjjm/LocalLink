import SwiftUI

struct BusinessProfileEditView: View {

    let businessId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BusinessProfileEditViewModel()
    @StateObject private var addressSearch = AddressSearchViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {

                // MARK: - Name
                TextField("Business name", text: $viewModel.businessName)
                    .textFieldStyle(.roundedBorder)

                // MARK: - Address + Autocomplete
                VStack(alignment: .leading, spacing: 6) {

                    TextField("Business address", text: $viewModel.address)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.address) {
                            addressSearch.update(query: $0)
                        }

                    if !addressSearch.results.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(addressSearch.results) { result in
                                    Button {
                                        selectAddress(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }

                // MARK: - Category
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("Select category").tag(BusinessCategory?.none)

                    ForEach(BusinessCategory.allCases) { category in
                        Text(category.rawValue).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)

                // MARK: - Base Town
                Picker("Base Town", selection: $viewModel.selectedTown) {
                    Text("Select town").tag(SupportedTown?.none)

                    ForEach(SupportedTown.allCases) { town in
                        Text(town.rawValue).tag(Optional(town))
                    }
                }
                .pickerStyle(.menu)

                // MARK: - Mobile Toggle
                Toggle("Mobile business (travels to customers)", isOn: $viewModel.isMobile)

                // MARK: - Service Towns (only if mobile)
                if viewModel.isMobile {

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Service towns")
                            .font(.headline)

                        ForEach(SupportedTown.allCases) { town in
                            MultipleSelectionRow(
                                title: town.rawValue,
                                isSelected: viewModel.selectedServiceTowns.contains(town)
                            ) {
                                toggleTown(town)
                            }
                        }
                    }
                }

                // MARK: - Active Toggle
                Toggle("Business is active", isOn: $viewModel.isActive)

                // MARK: - Error
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Save
                Button {
                    viewModel.save(businessId: businessId) {
                        dismiss()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save changes")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
            .padding()
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load(businessId: businessId)
        }
    }

    // MARK: - Helpers

    private func toggleTown(_ town: SupportedTown) {
        if viewModel.selectedServiceTowns.contains(town) {
            viewModel.selectedServiceTowns.remove(town)
        } else {
            viewModel.selectedServiceTowns.insert(town)
        }
    }

    private func selectAddress(_ result: AddressResult) {

        viewModel.address = "\(result.title), \(result.subtitle)"
        addressSearch.clear()

        Task {
            if let coordinate = await addressSearch.resolveCoordinate(for: result) {
                viewModel.latitude = coordinate.latitude
                viewModel.longitude = coordinate.longitude
            }
        }
    }
}
