import SwiftUI

struct CustomerBusinessSearchView: View {
    
    @State private var selectedCategory: BusinessCategory?
    @State private var selectedTown: SupportedTown?
    
    var body: some View {
        
        List {
            
            // MARK: - HEADER
            
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text("Find the right service")
                        .font(.headline)
                    
                    Text("Select a service and location to see available businesses.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - CATEGORY
            
            Section("Service") {
                
                ForEach(BusinessCategory.allCases) { category in
                    
                    Button {
                        selectedCategory = category
                    } label: {
                        
                        HStack(spacing: 12) {
                            
                            category.icon
                                .font(.title3)
                                .foregroundStyle(AppColors.primary)
                            
                            Text(category.rawValue)
                                .foregroundColor(.primary)
                            
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
            }
            
            // MARK: - TOWN
            
            Section("Location") {
                
                ForEach(SupportedTown.allCases) { town in
                    
                    Button {
                        selectedTown = town
                    } label: {
                        
                        HStack(spacing: 12) {
                            
                            Image(systemName: "map")
                                .foregroundStyle(AppColors.primary)
                            
                            Text(town.rawValue)
                                .foregroundColor(.primary)
                            
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
            }
            
            // MARK: - SEARCH CTA
            
            Section {
                
                NavigationLink {
                    
                    BusinessListView(
                        town: selectedTown?.rawValue,
                        category: selectedCategory?.rawValue
                    )
                    
                } label: {
                    
                    HStack(spacing: 12) {
                        
                        Image(systemName: "magnifyingglass")
                        
                        Text(formIsValid
                             ? "Show available services"
                             : "Select service and location")
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .font(.headline)
                    .padding(.vertical, 8)
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
    
    // MARK: - VALIDATION
    
    private var formIsValid: Bool {
        selectedCategory != nil && selectedTown != nil
    }
}
