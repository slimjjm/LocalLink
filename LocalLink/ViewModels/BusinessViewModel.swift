import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

final class BusinessViewModel: ObservableObject {

    // MARK: - Onboarding Fields
    @Published var businessName: String = ""
    @Published var businessDescription: String = ""
    @Published var serviceCategory: String = ""

    // Step 4 – Photo
    @Published var imageSelection: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var uploadedImageURL: String?

    // MARK: - State
    @Published var isSaving = false

    // MARK: - Validation
    var isFullyValid: Bool {
        !businessName.isEmpty &&
        !businessDescription.isEmpty &&
        !serviceCategory.isEmpty &&
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
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: -1)))
            return
        }

        let filename = UUID().uuidString + ".jpg"
        let ref = Storage.storage()
            .reference()
            .child("business_images/\(filename)")

        ref.putData(data) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            ref.downloadURL { url, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(url!.absoluteString))
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

        uploadImage(image) { [weak self] result in
            guard let self else { return }

            switch result {

            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Image upload failed:", error)
                    self.isSaving = false
                    completion(false)
                }

            case .success(let imageURL):
                self.uploadedImageURL = imageURL

                let businessData: [String: Any] = [
                    "businessName": self.businessName,
                    "businessDescription": self.businessDescription,
                    "serviceCategory": self.serviceCategory,
                    "imageURL": imageURL,
                    "ownerId": uid,                 // ✅ CRITICAL FIX
                    "createdAt": Timestamp()
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

