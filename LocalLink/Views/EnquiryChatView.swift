import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EnquiryChatView: View {
    
    // ✅ Supports BOTH entry paths
    private let business: Business?
    private let businessId: String
    
    @StateObject private var viewModel = EnquiryChatViewModel()
    @State private var messageText = ""
    @AppStorage("userRole") private var currentRole: String = "customer"
    // MARK: - INITS
    
    init(business: Business) {
        self.business = business
        self.businessId = business.id ?? ""
    }
    
    init(businessId: String) {
        self.business = nil
        self.businessId = businessId
    }
    
    // MARK: - BODY
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            messagesList
            
            Divider()
            
            messageInputBar
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start(
                businessId: businessId,
                role: currentRole
            )
        }
    }
}

// MARK: - MESSAGES

private extension EnquiryChatView {
    
    var messagesList: some View {
        
        ScrollViewReader { proxy in
            
            ScrollView {
                
                VStack(spacing: 10) {
                    
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                    }
                }
                .padding(.top, 10)
            }
            .onChange(of: viewModel.messages.count) { _ in
                
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
                
                // ✅ Mark as read when messages appear
                viewModel.markAsRead()
            }
        }
    }
}

// MARK: - MESSAGE ROW

private extension EnquiryChatView {
    
    func messageRow(_ message: ChatMessage) -> some View {
        
        HStack {
            
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .padding(12)
                .background(
                    message.isFromCurrentUser
                    ? AppColors.primary
                    : Color(.secondarySystemBackground)
                )
                .foregroundColor(
                    message.isFromCurrentUser ? .white : .primary
                )
                .cornerRadius(14)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .id(message.id)
    }
}

// MARK: - INPUT BAR

private extension EnquiryChatView {
    
    var messageInputBar: some View {
        
        HStack(spacing: 10) {
            
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(.roundedBorder)
            
            Button {
                send()
            } label: {
                Text("Send")
                    .fontWeight(.semibold)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
    
    func send() {
        
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        viewModel.send(text: text)
        messageText = ""
    }
}
