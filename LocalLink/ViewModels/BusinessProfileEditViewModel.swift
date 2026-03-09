import Foundation
import FirebaseFirestore
import MapKit

@MainActor
final class BusinessProfileEditViewModel: ObservableObject {

    // MARK: - Editable Fields

    @Published var businessName: String = ""
    @Published var address: String = ""
    @Published var selectedCategory: BusinessCategory?
    @Published var selectedTown: SupportedTown?

    @Published var isMobile: Bool = false
    @Published var selectedServiceTowns: Set<SupportedTown> = []

    @Published var isActive: Bool = true

    // Geo
    @Published var latitude: Double?
    @Published var longitude: Double?

    // UI
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()

    // MARK: - Load

    func load(businessId: String) {
        db.collection("businesses")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data() else { return }

                self.businessName = data["businessName"] as? String ?? ""
                self.address = data["address"] as? String ?? ""

                if let category = data["category"] as? String {
                    self.selectedCategory = BusinessCategory(rawValue: category)
                }

                if let town = data["town"] as? String {
                    self.selectedTown = SupportedTown(rawValue: town)
                }

                self.isMobile = data["isMobile"] as? Bool ?? false

                if let towns = data["serviceTowns"] as? [String] {
                    self.selectedServiceTowns =
                        Set(towns.compactMap { SupportedTown(rawValue: $0) })
                }

                self.latitude = data["latitude"] as? Double
                self.longitude = data["longitude"] as? Double

                self.isActive = data["isActive"] as? Bool ?? true
            }
    }

    // MARK: - Validation

    var isValid: Bool {
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedCategory != nil
        && selectedTown != nil
        && (!isMobile || !selectedServiceTowns.isEmpty)
    }

    // MARK: - Save

    func save(businessId: String, onComplete: @escaping () -> Void) {

        guard isValid else {
            errorMessage = "Please complete all required fields."
            return
        }

        guard let selectedCategory,
              let selectedTown else { return }

        isSaving = true
        errorMessage = ""

        let baseTown = selectedTown.rawValue

        let serviceTownValues: [String] =
            isMobile
            ? selectedServiceTowns.map { $0.rawValue }
            : [baseTown]

        let updates: [String: Any] = [
            "businessName": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": address,
            "category": selectedCategory.rawValue,
            "town": baseTown,
            "isMobile": isMobile,
            "serviceTowns": serviceTownValues,
            "latitude": latitude ?? NSNull(),
            "longitude": longitude ?? NSNull(),
            "isActive": isActive
        ]

        db.collection("businesses")
            .document(businessId)
            .setData(updates, merge: true) { [weak self] error in
                guard let self else { return }

                self.isSaving = false

                if let error {
                    self.errorMessage = error.localizedDescription
                } else {
                    onComplete()
                }
            }
    }
}
