import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

final class BusinessViewModel: ObservableObject {

    // MARK: - Onboarding Fields
    @Published var businessName: String = ""
    @Published var bio: String = ""
    @Published var category: String = ""
    @Published var photoURLs: [String] = []

    // MARK: - Image
    @Published var imageSelection: PhotosPickerItem?
    @Published var selectedImage: UIImage?

    // MARK: - State
    @Published var isSaving = false

    // MARK: - Validation
    var isFullyValid: Bool {
        !businessName.isEmpty &&
        !bio.isEmpty &&
        !category.isEmpty &&
        selectedImage != nil
    }

    // MARK: - Image Picker
    func loadImage() {
        guard let imageSelection else { return }

        Task {
            if let data = try? await imageSelection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = image
                }
            }
        }
    }

    // MARK: - Image Upload
    private func uploadImage(
        _ image: UIImage,
        userId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: -1)))
            return
        }

        let filename = UUID().uuidString + ".jpg"

        let ref = Storage.storage()
            .reference()
            .child("business_images/\(userId)/\(filename)") // ✅ FIXED

        ref.putData(data, metadata: nil) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            ref.downloadURL { url, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let url else {
                    completion(.failure(NSError(domain: "URL Error", code: -2)))
                    return
                }

                completion(.success(url.absoluteString))
            }
        }
    }

    // MARK: - Save Business
    func saveBusiness(completion: @escaping (Bool) -> Void) {

        guard isFullyValid else {
            print("❌ Validation failed")
            completion(false)
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            completion(false)
            return
        }

        guard let image = selectedImage else {
            completion(false)
            return
        }

        isSaving = true

        uploadImage(image, userId: uid) { [weak self] result in
            guard let self else { return }

            switch result {

            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Image upload failed:", error)
                    self.isSaving = false
                    completion(false)
                }

            case .success(let imageURL):

                let businessData: [String: Any] = [
                    "businessName": self.businessName,
                    "bio": self.bio,
                    "category": self.category,
                    "photoURLs": [imageURL],

                    "town": "",
                    "isMobile": false,
                    "serviceTowns": [],

                    "isActive": true,
                    "verified": false,

                    "ownerId": uid,
                    "createdAt": Timestamp(),

                    // Ratings
                    "ratingPositiveCount": 0,
                    "ratingNegativeCount": 0
                ]

                Firestore.firestore()
                    .collection("businesses")
                    .addDocument(data: businessData) { error in
                        DispatchQueue.main.async {
                            self.isSaving = false

                            if let error {
                                print("❌ Firestore save failed:", error)
                                completion(false)
                            } else {
                                print("✅ Business saved successfully")
                                completion(true)
                            }
                        }
                    }
            }
        }
    }
}
