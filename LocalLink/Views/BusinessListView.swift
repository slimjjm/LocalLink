import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessListView: View {

    // MARK: - State
    @State private var businesses: [FirestoreBusiness] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // MARK: - Firestore
    private let db = Firestore.firestore()

    var body: some View {
        List {

            // Header section (polish)
            Section {
                Text("Local businesses")
                    .font(.headline)
            }

            // Loading
            if isLoading {
                Section {
                    ProgressView("Loading businesses…")
                }
            }

            // Error
            else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            // Empty
            else if businesses.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No businesses yet",
                        systemImage: "building.2",
                        description: Text("Local businesses will appear here once they join.")
                    )
                }
            }

            // Results
            else {
                Section {
                    ForEach(businesses) { business in
                        if let businessId = business.id {
                            NavigationLink {
                                CustomerServiceListView(businessId: businessId)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(business.businessName)
                                        .font(.headline)

                                    Text(business.address)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
        .onAppear(perform: loadBusinesses)
    }

    // MARK: - Load businesses

    private func loadBusinesses() {
        isLoading = true
        errorMessage = nil

        db.collection("businesses")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in

                isLoading = false

                if let error {
                    errorMessage = error.localizedDescription
                    return
                }

                businesses = snapshot?.documents.compactMap {
                    try? $0.data(as: FirestoreBusiness.self)
                } ?? []
            }
    }
}


