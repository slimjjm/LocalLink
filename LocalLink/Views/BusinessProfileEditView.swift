import SwiftUI
import PhotosUI
import FirebaseStorage
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

struct BusinessProfileEditView: View {
    
    let businessId: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BusinessProfileEditViewModel()
    @StateObject private var addressSearch = AddressSearchViewModel()
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
    @State private var selectedImage: UIImage?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                nameSection
                bioSection
                addressSection
                photosSection
                categorySection
                townSection
                settingsSection
                errorSection
                saveSection
            }
            .padding()
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load(businessId: businessId)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }

            isUploading = true

            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {

                        // ✅ STORE IMAGE FOR UPLOAD
                        selectedImage = image

                        // ✅ NOW UPLOAD
                        await uploadImage(businessId: businessId)
                    }
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }

                isUploading = false
            }
        }
    }
}

// MARK: - Sections

private extension BusinessProfileEditView {
    
    var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Business name")
                .font(.headline)
            
            TextField("e.g. Elite Cuts Barber", text: $viewModel.businessName)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    var bioSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About your business")
                .font(.headline)
            
            TextEditor(text: $viewModel.bio)
                .frame(height: 120)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onChange(of: viewModel.bio) { newValue in
                    if newValue.count > 200 {
                        viewModel.bio = String(newValue.prefix(200))
                    }
                }
            
            HStack {
                Spacer()
                Text("\(viewModel.bio.count)/200")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var addressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Address")
                .font(.headline)
            
            TextField("Search address", text: $viewModel.address)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.address) { newValue in
                    addressSearch.update(query: newValue)
                }
            
            if !addressSearch.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(addressSearch.results) { result in
                        Button {
                            selectAddress(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - PHOTOS (NEW PREMIUM LAYOUT)

    var photosSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Photos")
                .font(.headline)

            // COVER IMAGE
            if let coverURL = viewModel.photoURLs.first,
               let url = URL(string: coverURL) {

                ZStack(alignment: .topTrailing) {

                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            Color(.secondarySystemBackground)
                            ProgressView()
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16)

                    Button {
                        Task {
                            await viewModel.deletePhoto(businessId: businessId, at: 0)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)

                    Text("Cover")
                        .font(.caption.bold())
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }

            // THUMBNAILS
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {

                    ForEach(viewModel.photoURLs.indices.dropFirst(), id: \.self) { index in
                        BusinessPhotoTile(
                            urlString: viewModel.photoURLs[index],
                            isCover: false,
                            onDelete: {
                                Task {
                                    await viewModel.deletePhoto(businessId: businessId, at: index)
                                }
                            }
                        )
                        .onDrag {
                            NSItemProvider(object: viewModel.photoURLs[index] as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: PhotoDropDelegate(
                                item: viewModel.photoURLs[index],
                                items: $viewModel.photoURLs,
                                currentIndex: index
                            )
                        )
                    }

                    if viewModel.photoURLs.count < 5 {
                        addPhotoButton
                    }
                }
            }

            Text("Drag photos to reorder. First photo is your cover.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    var addPhotoButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            VStack(spacing: 6) {
                if isUploading {
                    ProgressView()
                } else {
                    Image(systemName: "plus")
                    Text("Add")
                        .font(.caption)
                }
            }
            .frame(width: 110, height: 110)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .disabled(isUploading)
    }
    
    var categorySection: some View {
        Picker("Category", selection: $viewModel.selectedCategory) {
            ForEach(BusinessCategory.allCases) { category in
                Text(category.rawValue).tag(category as BusinessCategory?)
            }
        }
        .pickerStyle(.menu)
    }
    
    var townSection: some View {
        Picker("Town", selection: $viewModel.selectedTown) {
            ForEach(SupportedTown.allCases) { town in
                Text(town.rawValue).tag(town as SupportedTown?)
            }
        }
        .pickerStyle(.menu)
    }
    
    var settingsSection: some View {
        VStack {
            Toggle("Mobile business", isOn: $viewModel.isMobile)
            Toggle("Business active", isOn: $viewModel.isActive)
        }
    }
    
    var errorSection: some View {
        Text(viewModel.errorMessage)
            .foregroundColor(.red)
    }
    
    var saveSection: some View {
        Button {
            viewModel.save(businessId: businessId) {
                dismiss()
            }
        } label: {
            Text(viewModel.isSaving ? "Saving..." : "Save changes")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Actions

private extension BusinessProfileEditView {
    
    func uploadImage(businessId: String) async {
        guard
            let image = selectedImage,
            let data = image.jpegData(compressionQuality: 0.7),
            let uid = Auth.auth().currentUser?.uid
        else {
            viewModel.errorMessage = "No image selected"
            return
        }

        let fileName = UUID().uuidString + ".jpg"
        let path = "businessPhotos/\(businessId)/\(fileName)"
        let ref = Storage.storage().reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "ownerId": uid
        ]

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            try await viewModel.appendUploadedPhotoAndPersist(
                businessId: businessId,
                urlString: url.absoluteString
            )
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
    func selectAddress(_ result: AddressResult) {
        viewModel.address = "\(result.title), \(result.subtitle)"
        addressSearch.clear()
    }
}

// MARK: - Photo Tile

private struct BusinessPhotoTile: View {
    
    let urlString: String
    let isCover: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            AsyncImage(url: URL(string: urlString)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.secondarySystemBackground)
            }
            .frame(width: 110, height: 110)
            .clipped()
            .cornerRadius(14)
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
            }
        }
    }
}
