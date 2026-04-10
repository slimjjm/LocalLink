import SwiftUI

struct InboxView: View {
    
    let businessId: String
    
    @StateObject private var viewModel = InboxViewModel()
    @AppStorage("userRole") private var currentRole: String = "customer"
    
    var body: some View {
        
        List {
            
            if viewModel.conversations.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.conversations) { convo in
                    NavigationLink {
                        EnquiryChatView(
                            businessId: convo.businessId,
                            customerId: convo.customerId
                        )
                    } label: {
                        row(convo)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Inbox")
        .onAppear {
            viewModel.startListening(
                role: currentRole,
                businessId: businessId
            )
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}
private extension InboxView {
    
    var emptyState: some View {
        VStack(spacing: 12) {
            
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No messages yet")
                .font(.headline)
            
            Text("Your conversations will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
}
private extension InboxView {
    
    func row(_ convo: Conversation) -> some View {
        
        HStack(spacing: 12) {
            
            Circle()
                .fill(AppColors.primary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "message.fill")
                        .foregroundColor(AppColors.primary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                
                HStack {
                    Text(convo.title)
                        .font(.subheadline.weight(.semibold))
                    
                    Spacer()
                    
                    Text(convo.timeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(convo.lastMessage)
                    .font(convo.unreadCount > 0 ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundColor(convo.unreadCount > 0 ? AppColors.charcoal : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if convo.unreadCount > 0 {
                Text("\(convo.unreadCount)")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}
