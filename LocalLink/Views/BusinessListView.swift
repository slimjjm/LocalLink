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
            
            if isLoading {
                ProgressView("Loading businesses…")
            }
            
            else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            else if businesses.isEmpty {
                ContentUnavailableView(
                    "No businesses yet",
                    systemImage: "building.2",
                    description: Text("Businesses will appear here once they join.")
                )
            }
            
            else {
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
                        }
                    }
                }
            }
        }
        .navigationTitle("Select a business")
        .onAppear {
            loadBusinesses()
        }
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

