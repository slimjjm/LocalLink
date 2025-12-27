import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct BusinessDocumentUploadView: View {

    @State private var selectedItem: PhotosPickerItem?
    @State private var uploadURL: String?

    var body: some View {
        VStack(spacing: 20) {

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Select Business Document")
            }

            Button("Upload") {
                uploadDocument()
            }
            .buttonStyle(.borderedProminent)
            .padding()

        }
    }

    func uploadDocument() {
        guard let item = selectedItem else { return }

        Task {
            do {
                // Load data
                guard let data = try await item.loadTransferable(type: Data.self) else { return }

                guard let userId = Auth.auth().currentUser?.uid else { return }
                let path = "businessDocuments/\(userId)/proof.jpg"
                let ref = Storage.storage().reference().child(path)

                // Upload to Firebase
                try await ref.putDataAsync(data)

                // Get download URL
                let url = try await ref.downloadURL()

                // Save URL to Firestore
                try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .updateData([
                        "businessDocumentURL": url.absoluteString
                    ])

                print("✅ Document uploaded and saved!")

            } catch {
                print("❌ Upload failed:", error.localizedDescription)
            }
        }
    }
}
