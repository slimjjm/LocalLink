import SwiftUI
import PhotosUI
import FirebaseFirestore

struct BusinessPhotoUploadView: View {

    let businessId: String

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isUploading = false

    private let db = Firestore.firestore()

    var body: some View {

        VStack(spacing: 20) {

            Text("Add photos")
                .font(.title2.bold())

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Text("Select photos")
                    .primaryButton()
            }

            if !images.isEmpty {

                ScrollView(.horizontal) {
                    HStack {
                        ForEach(images, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(12)
                        }
                    }
                }
            }

            if isUploading {
                ProgressView("Uploading…")
            }

            Button("Upload") {
                uploadImages()
            }
            .primaryButton()
            .disabled(images.isEmpty || isUploading)

            Spacer()
        }
        .padding()
        .onChange(of: selectedItems) { _ in
            loadImages()
        }
    }
}

// MARK: - Logic

private extension BusinessPhotoUploadView {

    func loadImages() {

        images.removeAll()

        for item in selectedItems {

            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {

                    await MainActor.run {
                        images.append(image)
                    }
                }
            }
        }
    }

    func uploadImages() {

        isUploading = true

        var uploadedURLs: [String] = []
        let group = DispatchGroup()

        for image in images {

            group.enter()

            StorageService.shared.uploadBusinessImage(
                businessId: businessId,
                image: image
            ) { result in

                if case .success(let url) = result {
                    uploadedURLs.append(url)
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {

            db.collection("businesses")
                .document(businessId)
                .updateData([
                    "photoURLs": FieldValue.arrayUnion(uploadedURLs)
                ])

            isUploading = false
        }
    }
}
