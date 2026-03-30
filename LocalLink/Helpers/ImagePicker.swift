import SwiftUI
import PhotosUI

struct PhotoPicker: View {
    
    @Binding var selectedImage: UIImage?
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        
        PhotosPicker(
            selection: $selectedItem,
            matching: .images
        ) {
            EmptyView()
        }
        .onChange(of: selectedItem) { newItem in
            guard let newItem else { return }
            
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    selectedImage = uiImage
                }
            }
        }
    }
}
