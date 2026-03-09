import SwiftUI

struct CustomerBusinessSearchView: View {

    @State private var selectedCategory: BusinessCategory?
    @State private var selectedTown: SupportedTown?

    var body: some View {

        List {

            // MARK: Category Section

            Section {

                ForEach(BusinessCategory.allCases, id: \.self) { category in

                    Button {

                        selectedCategory = category

                    } label: {

                        HStack {

                            Label(
                                category.rawValue,
                                systemImage: category.icon
                            )

                            Spacer()

                            if selectedCategory == category {

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            } header: {

                Text("Service")
            }

            // MARK: Town Section

            Section {

                ForEach(SupportedTown.allCases, id: \.self) { town in

                    Button {

                        selectedTown = town

                    } label: {

                        HStack {

                            Label(
                                town.rawValue,
                                systemImage: "map"
                            )

                            Spacer()

                            if selectedTown == town {

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

            } header: {

                Text("Town")
            }

            // MARK: Search Button

            Section {

                NavigationLink {

                    BusinessListView(
                        town: selectedTown?.rawValue,
                        category: selectedCategory?.rawValue
                    )

                } label: {

                    HStack {

                        Image(systemName: "magnifyingglass")

                        Text("Search")

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .font(.headline)
                    .padding(.vertical, 6)
                }
                .disabled(!formIsValid)

            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formIsValid: Bool {

        selectedCategory != nil && selectedTown != nil
    }
}
