import Foundation
import FirebaseFirestore
import FirebaseStorage
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
    @Published var bio: String = ""
    @Published var photoURLs: [String] = []

    // Geo

    @Published var latitude: Double?
    @Published var longitude: Double?

    // UI

    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

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

                self.bio = data["bio"] as? String ?? ""
                self.isMobile = data["isMobile"] as? Bool ?? false
                self.isActive = data["isActive"] as? Bool ?? true

                if let towns = data["serviceTowns"] as? [String] {
                    self.selectedServiceTowns = Set(
                        towns.compactMap { SupportedTown(rawValue: $0) }
                    )
                } else {
                    self.selectedServiceTowns = []
                }

                self.latitude = data["latitude"] as? Double
                self.longitude = data["longitude"] as? Double
                self.photoURLs = data["photoURLs"] as? [String] ?? []
            }
    }

    // MARK: - Validation

    var isValid: Bool {
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCategory != nil &&
        selectedTown != nil &&
        (!isMobile || !selectedServiceTowns.isEmpty)
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

        let trimmedName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseTown = selectedTown.rawValue

        let serviceTownValues: [String] = isMobile
            ? selectedServiceTowns.map { $0.rawValue }.sorted()
            : [baseTown]

        let updates: [String: Any] = [
            "businessName": trimmedName,
            "address": trimmedAddress,
            "category": selectedCategory.rawValue,
            "town": baseTown,
            "isMobile": isMobile,
            "serviceTowns": serviceTownValues,
            "latitude": latitude ?? NSNull(),
            "longitude": longitude ?? NSNull(),
            "isActive": isActive,
            "bio": trimmedBio,
            "photoURLs": photoURLs
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

    // MARK: - Photo Helpers

    func addPhotoURL(_ url: String) {
        guard photoURLs.count < 5 else { return }
        photoURLs.append(url)
    }

    func removePhotoLocally(at index: Int) {
        guard photoURLs.indices.contains(index) else { return }
        photoURLs.remove(at: index)
    }

    func persistPhotoOrder(businessId: String) async throws {
        try await db.collection("businesses")
            .document(businessId)
            .setData([
                "photoURLs": photoURLs
            ], merge: true)
    }

    func deletePhoto(businessId: String, at index: Int) async {
        guard photoURLs.indices.contains(index) else { return }

        errorMessage = ""

        let urlString = photoURLs[index]

        do {
            let ref = try storage.reference(forURL: urlString)

            try await ref.delete()

            photoURLs.remove(at: index)

            try await db.collection("businesses")
                .document(businessId)
                .setData([
                    "photoURLs": photoURLs
                ], merge: true)
        } catch {
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
        }
    }

    func appendUploadedPhotoAndPersist(businessId: String, urlString: String) async throws {
        guard photoURLs.count < 5 else { return }

        photoURLs.append(urlString)

        try await db.collection("businesses")
            .document(businessId)
            .setData([
                "photoURLs": photoURLs
            ], merge: true)
    }
}
