import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct InboxView: View {
    
    @StateObject private var viewModel = InboxViewModel()
    
    var body: some View {
        List {
            
            ForEach(viewModel.conversations) { convo in
                
                NavigationLink {
                    BookingChatView(
                        bookingId: convo.bookingId,
                        businessId: "",
                        customerId: "",
                        currentUserRole: "customer"
                    )
                } label: {
                    row(convo)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Inbox")
        .onAppear {
            viewModel.startListening()
        }
    }
}

// MARK: - ROW

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
