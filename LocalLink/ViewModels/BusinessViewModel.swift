import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

class BusinessViewModel: ObservableObject {

    // MARK: - Published fields for your onboarding steps
    @Published var businessName: String = ""
    @Published var businessDescription: String = ""
    @Published var serviceCategory: String = ""

    // Step 4 – Photo
    @Published var imageSelection: PhotosPickerItem? = nil
    @Published var selectedImage: UIImage? = nil
    @Published var uploadedImageURL: String? = nil

    // MARK: - Loading and completion state
    @Published var isSaving: Bool = false

    // MARK: - Validation
    var isFullyValid: Bool {
        return !businessName.isEmpty &&
               !businessDescription.isEmpty &&
               !serviceCategory.isEmpty &&
               selectedImage != nil
    }

    // MARK: - Handle Image Picker
    func loadImage() {
        guard let imageSelection else { return }

        Task {
            if let data = try? await imageSelection.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = uiImage
                }
            }
        }
    }

    // MARK: - Upload image to Firebase Storage
    private func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }

        let filename = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("business_images/\(filename)")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("❌ Failed to upload image:", error)
                completion(nil)
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get download URL:", error)
                    completion(nil)
                    return
                }
                completion(url?.absoluteString)
            }
        }
    }

    // MARK: - Save Business to Firestore
    func saveBusiness(completion: @escaping (Bool) -> Void) {

        guard isFullyValid else {
            print("❌ All fields required")
            completion(false)
            return
        }

        isSaving = true

        guard let imageToUpload = selectedImage else {
            print("❌ No image selected")
            completion(false)
            return
        }

        // STEP 1 — Upload image
        uploadImage(imageToUpload) { [weak self] imageURL in
            guard let self = self else { return }

            if imageURL == nil {
                DispatchQueue.main.async {
                    self.isSaving = false
                    completion(false)
                }
                return
            }

            self.uploadedImageURL = imageURL

            // STEP 2 — Save business document
            let db = Firestore.firestore()
            let businessData: [String: Any] = [
                "businessName": self.businessName,
                "businessDescription": self.businessDescription,
                "serviceCategory": self.serviceCategory,
                "imageURL": imageURL!,
                "createdAt": Timestamp()
            ]

            db.collection("businesses").addDocument(data: businessData) { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if let error = error {
                        print("❌ Firestore save failed:", error)
                        completion(false)
                    } else {
                        print("✅ Business saved successfully!")
                        completion(true)
                    }
                }
            }
        }
    }
}
