import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class CustomerBusinessListViewModel: ObservableObject {

    @Published var businesses: [Business] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private var hasLoaded = false
    private var lastTown: String?
    private var lastCategory: String?

    func loadBusinesses(town: String? = nil, category: String? = nil) {

        print("🚀 loadBusinesses CALLED")
        print("🔍 town filter:", town ?? "nil")
        print("🔍 category filter:", category ?? "nil")

        if hasLoaded,
           lastTown == town,
           lastCategory == category {
            print("⏭ Skipping load (already loaded with same filters)")
            return
        }

        hasLoaded = true
        lastTown = town
        lastCategory = category

        isLoading = true
        errorMessage = nil
        businesses = []

        var query: Query = db.collection("businesses")

        if let town, !town.isEmpty {
            print("✅ Applying town filter:", town)
            query = query.whereField("town", isEqualTo: town)
        }

        if let category, !category.isEmpty {
            print("✅ Applying category filter:", category)
            query = query.whereField("category", isEqualTo: category)
        }

        print("📡 Executing Firestore query...")

        query
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }

                self.isLoading = false

                if let error {
                    print("❌ Firestore ERROR:", error.localizedDescription)
                    self.errorMessage = "Failed to load businesses"
                    return
                }

                let docs = snapshot?.documents ?? []

                print("📄 Raw documents returned:", docs.count)

                for doc in docs {
                    print("📦 Doc ID:", doc.documentID)
                }

                // ✅ CORRECT decoding (THIS FIXES YOUR APP)
                let decoded: [Business] = docs.compactMap { doc in
                    do {
                        let business = try doc.data(as: Business.self)
                        print("✅ Business loaded:", business.businessName, "| ID:", business.id ?? "nil")
                        return business
                    } catch {
                        print("❌ Decode failed:", error)
                        return nil
                    }
                }

                // 🔥 Remove duplicates safely
                var seen = Set<String>()
                let unique = decoded.filter { business in
                    guard let id = business.id else { return false }
                    if seen.contains(id) { return false }
                    seen.insert(id)
                    return true
                }

                self.businesses = unique

                print("✅ Final businesses count:", unique.count)

                for b in unique {
                    print("→", b.id ?? "nil", "|", b.businessName)
                }
            }
    }

    func forceReload(town: String? = nil, category: String? = nil) {
        print("🔁 FORCE RELOAD TRIGGERED")
        hasLoaded = false
        loadBusinesses(town: town, category: category)
    }
}
