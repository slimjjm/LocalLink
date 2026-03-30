import SwiftUI
import FirebaseFirestore

struct BusinessListView: View {

    let town: String?
    let category: String?
     
        
    @StateObject private var viewModel = CustomerBusinessListViewModel()

    // 🔥 Cache
    @State private var servicesCache: [String: [BusinessService]] = [:]
    @State private var slotCache: [String: Date] = [:]

    private let slotService = NextAvailableSlotService()

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

            // MARK: - Error
            } else if let error = viewModel.errorMessage {

                Section {
                    Text(error)
                        .foregroundColor(.red)
                }

            // MARK: - Empty
            } else if viewModel.businesses.isEmpty {

                Section {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass"
                    )
                }

            // MARK: - Results
            } else {

                Section {
                    ForEach(viewModel.businesses) { business in
                        BusinessListRow(
                            business: business,
                            servicesCache: servicesCache,
                            slotCache: slotCache
                        )
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

        // 🔥 PRELOAD
        .onChange(of: viewModel.businesses) { businesses in
            preloadData(for: businesses)
        }
    }
}

// MARK: - ROW VIEW

struct BusinessListRow: View {
    
    let business: Business
    let servicesCache: [String: [BusinessService]]
    let slotCache: [String: Date]

    var body: some View {
        
        let businessId = business.id ?? ""
        let services = servicesCache[businessId] ?? []
        let nextSlot = slotCache[businessId]

        NavigationLink {

            BusinessProfileContainerView(businessId: business.id ?? "")

        } label: {

            BusinessRowView(
                business: business,
                nextSlot: nextSlot
            )
        }
    }
}

// MARK: - PRELOAD

private extension BusinessListView {

    func preloadData(for businesses: [Business]) {

        for business in businesses {

            guard let id = business.id else { continue }

            // Skip if already cached
            if servicesCache[id] != nil { continue }

            // 🔹 SERVICES
            Firestore.firestore()
                .collection("businesses")
                .document(id)
                .collection("services")
                .whereField("isActive", isEqualTo: true)
                .getDocuments { snapshot, _ in

                    let services: [BusinessService] = snapshot?.documents.compactMap {
                        try? $0.data(as: BusinessService.self)
                    } ?? []

                    DispatchQueue.main.async {
                        servicesCache[id] = services
                    }
                }

            // 🔹 NEXT SLOT
            slotService.fetchNextSlot(businessId: id) { slot in
                DispatchQueue.main.async {
                    slotCache[id] = slot
                }
            }
        }
    }
}
