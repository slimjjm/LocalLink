import Foundation
import FirebaseFirestore

@MainActor
final class BusinessProfileEditViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var contactNumber: String = ""
    @Published var isActive: Bool = true

    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()

    func load(businessId: String) {
        db.collection("businesses").document(businessId).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            guard let data = snapshot?.data() else { return }

            // ✅ Canonical field
            let canonicalName = data["name"] as? String

            // 🧠 Legacy fallback (from onboarding)
            let legacyName = data["businessName"] as? String

            self.name = canonicalName ?? legacyName ?? ""
            self.contactNumber = data["contactNumber"] as? String ?? ""
            self.isActive = data["isActive"] as? Bool ?? true
        }
    }

    func save(businessId: String, onComplete: @escaping () -> Void) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSaving = true

        let updates: [String: Any] = [
            // ✅ Standardised field going forward
            "name": name.trimmingCharacters(in: .whitespaces),
            "contactNumber": contactNumber,
            "isActive": isActive
        ]

        db.collection("businesses")
            .document(businessId)
            .setData(updates, merge: true) { [weak self] error in
                guard let self else { return }

                self.isSaving = false

                if error == nil {
                    onComplete()
                }
            }
    }
}
