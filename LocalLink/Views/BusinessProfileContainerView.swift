import SwiftUI
import FirebaseAuth

struct BusinessProfileContainerView: View {
    
    let businessId: String
    
    @StateObject private var viewModel = BusinessProfileViewModel()
    
    var body: some View {
        
        Group {
            
            if viewModel.isLoading {
                
                ProgressView()
                    .tint(AppColors.primary)
                
            } else if let business = viewModel.business {
                
                BusinessProfileView(
                    business: business,
                    nextSlot: nil
                )
                
            } else if !viewModel.errorMessage.isEmpty {
                
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                        .font(.system(size: 28))
                    
                    Text(viewModel.errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
            } else {
                
                Text("Something went wrong")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        
        // 🔥 EDIT BUTTON
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                
                if viewModel.business?.ownerId == Auth.auth().currentUser?.uid {
                    
                    NavigationLink {
                        BusinessProfileEditView(businessId: businessId)
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        
        .background(AppColors.background.ignoresSafeArea())
        
        .task {
            viewModel.load(businessId: businessId)
        }
    }
}
