import SwiftUI
import PhotosUI
import FirebaseStorage
import UniformTypeIdentifiers
import FirebaseAuth

struct BusinessProfileEditView: View {
    
    let businessId: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BusinessProfileEditViewModel()
    @StateObject private var addressSearch = AddressSearchViewModel()
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
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
            guard newItem != nil else { return }
            
            Task {
                await uploadImage(businessId: businessId)
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
                                    .foregroundColor(.primary)
                                
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if result.id != addressSearch.results.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    
                    ForEach(viewModel.photoURLs.indices, id: \.self) { index in
                        BusinessPhotoTile(
                            urlString: viewModel.photoURLs[index],
                            isCover: index == 0,
                            onDelete: {
                                viewModel.removePhoto(at: index)
                            }
                        )
                        .onDrag {
                            NSItemProvider(object: "\(index)" as NSString)
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
            
            Text("Add up to 5 photos")
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
                        .font(.title3)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.headline)
            
            Picker("Category", selection: $viewModel.selectedCategory) {
                Text("Select category")
                    .tag(nil as BusinessCategory?)
                
                ForEach(BusinessCategory.allCases) { category in
                    Text(category.rawValue)
                        .tag(category as BusinessCategory?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var townSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Base Town")
                .font(.headline)
            
            Picker("Base Town", selection: $viewModel.selectedTown) {
                Text("Select town")
                    .tag(nil as SupportedTown?)
                
                ForEach(SupportedTown.allCases) { town in
                    Text(town.rawValue)
                        .tag(town as SupportedTown?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var settingsSection: some View {
        VStack(spacing: 12) {
            Toggle("Mobile business", isOn: $viewModel.isMobile)
            Toggle("Business is active", isOn: $viewModel.isActive)
        }
    }
    
    @ViewBuilder
    var errorSection: some View {
        if !viewModel.errorMessage.isEmpty {
            Text(viewModel.errorMessage)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var saveSection: some View {
        Button {
            viewModel.save(businessId: businessId) {
                dismiss()
            }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save changes")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isValid || viewModel.isSaving || isUploading)
    }
}

// MARK: - Actions

private extension BusinessProfileEditView {
    
    func uploadImage(businessId: String) async {
        guard let item = selectedItem else { return }

        // 🔍 DEBUG
        print("📸 Upload started")
        print("➡️ businessId:", businessId)
        print("➡️ auth uid:", Auth.auth().currentUser?.uid ?? "nil")

        isUploading = true

        defer {
            isUploading = false
            selectedItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressed = image.jpegData(compressionQuality: 0.7) else {
                viewModel.errorMessage = "Failed to prepare image."
                print("❌ Image preparation failed")
                return
            }

            let fileName = UUID().uuidString + ".jpg"
            let path = "businessPhotos/\(businessId)/\(fileName)"

            // 🔍 DEBUG
            print("📂 Upload path:", path)

            let ref = Storage.storage()
                .reference()
                .child(path)

            print("⬆️ Starting upload...")

            _ = try await ref.putDataAsync(compressed)

            print("✅ Upload success")

            let url = try await ref.downloadURL()

            print("🌍 Download URL:", url.absoluteString)

            viewModel.addPhotoURL(url.absoluteString)

        } catch {
            viewModel.errorMessage = error.localizedDescription
            print("❌ Upload failed:", error.localizedDescription)
        }
    }
    
    func selectAddress(_ result: AddressResult) {
        viewModel.address = "\(result.title), \(result.subtitle)"
        addressSearch.clear()
        
        Task {
            if let coordinate = await addressSearch.resolveCoordinate(for: result) {
                viewModel.latitude = coordinate.latitude
                viewModel.longitude = coordinate.longitude
            }
        }
    }
}// MARK: - Photo Tile

private struct BusinessPhotoTile: View {
    
    let urlString: String
    let isCover: Bool
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            AsyncImage(url: URL(string: urlString)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color(.secondarySystemBackground)
                    ProgressView()
                }
            }
            .frame(width: 110, height: 110)
            .clipped()
            .cornerRadius(14)
            .overlay(alignment: .bottomLeading) {
                if isCover {
                    coverBadge
                        .padding(6)
                }
            }
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: 6, y: -6)
        }
    }
    
    private var coverBadge: some View {
        Text("Cover")
            .font(.caption2.bold())
            .padding(6)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}
