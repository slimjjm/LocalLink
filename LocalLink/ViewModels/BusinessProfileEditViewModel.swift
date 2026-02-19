import Foundation
import FirebaseFirestore

@MainActor
final class BusinessProfileEditViewModel: ObservableObject {

    // MARK: - Editable fields
    @Published var name: String = ""
    @Published var contactNumber: String = ""
    @Published var serviceArea: String = ""
    @Published var isActive: Bool = true

    // MARK: - UI State
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()

    // MARK: - Load
    func load(businessId: String) {
        db.collection("businesses").document(businessId).getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            guard let data = snapshot?.data() else { return }

            // Canonical name
            let canonicalName = data["name"] as? String
            let legacyName = data["businessName"] as? String

            self.name = canonicalName ?? legacyName ?? ""
            self.contactNumber = data["contactNumber"] as? String ?? ""
            self.serviceArea = data["serviceArea"] as? String ?? ""
            self.isActive = data["isActive"] as? Bool ?? true
        }
    }

    // MARK: - Save
    func save(businessId: String, onComplete: @escaping () -> Void) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Business name is required."
            return
        }

        isSaving = true
        errorMessage = ""

        let updates: [String: Any] = [
            "name": trimmedName,
            "contactNumber": contactNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "serviceArea": serviceArea.trimmingCharacters(in: .whitespacesAndNewlines),
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

