import SwiftUI
import FirebaseFirestore

struct BusinessInboxView: View {
    
    let businessId: String
    
    @StateObject private var viewModel = BusinessInboxViewModel()
    
    var body: some View {
        
        List {
            
            if viewModel.chats.isEmpty {
                
                VStack(spacing: 12) {
                    
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No enquiries yet")
                        .font(.headline)
                    
                    Text("When customers message you, they’ll appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            
            ForEach(viewModel.chats) { chat in
                
                NavigationLink {
                    
                    EnquiryChatView(
                        businessId: businessId,
                        customerId: chat.customerId   // 👈 REQUIRED
                    )
                } label: {
                    
                    HStack {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            
                            Text(chat.previewName)
                                .font(.headline)
                            
                            Text(chat.lastMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.caption.bold())
                                .padding(8)
                                .background(AppColors.error)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start(businessId: businessId)
        }
    }
}

