import SwiftUI
import FirebaseAuth

struct EnquiryChatView: View {
    
    let businessId: String
    let customerId: String
    
    @StateObject private var viewModel = EnquiryChatViewModel()
    @State private var messageText = ""
    
    @AppStorage("userRole") private var currentRole: String = "customer"
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            messagesList
            
            Divider()
            
            // 🔥 ERROR DISPLAY (THIS IS THE FIX)
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
            
            messageInputBar
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🚀 OPENING CHAT FOR: \(businessId)")
            print("💬 CHAT ID:", "\(businessId)_\(customerId)")
            viewModel.start(
                businessId: businessId,
                customerId: customerId,
                role: currentRole
            )
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .onChange(of: viewModel.messages.count) { _ in
            viewModel.markAsRead()
        }
    }
}

func chatId(businessId: String, customerId: String) -> String {
    "\(businessId)_\(customerId)"
}

// MARK: - MESSAGES

private extension EnquiryChatView {
    
    var messagesList: some View {
        
        ScrollViewReader { proxy in
            
            ScrollView {
                
                LazyVStack(spacing: 10) {
                    
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No messages yet")
                .font(.headline)
            
            Text("Start the conversation below")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

// MARK: - MESSAGE ROW

private extension EnquiryChatView {
    
    func messageRow(_ message: ChatMessage) -> some View {
        
        let isMe = message.senderRole == currentRole
        
        return HStack(alignment: .bottom) {
            
            if isMe { Spacer(minLength: 50) }
            
            VStack(alignment: .leading, spacing: 4) {
                
                if !isMe {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isMe ? .white : .primary)
                    
                    Text(timeString(from: message.createdAt))
                        .font(.caption2)
                        .foregroundColor(isMe ? .white.opacity(0.8) : .secondary)
                }
                .padding(10)
                .background(
                    isMe
                    ? AppColors.primary
                    : Color(.secondarySystemBackground)
                )
                .cornerRadius(14)
            }
            .frame(maxWidth: 260, alignment: isMe ? .trailing : .leading)
            
            if !isMe { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - INPUT

private extension EnquiryChatView {
    
    var messageInputBar: some View {
        
        HStack(spacing: 10) {
            
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            
            Button {
                send()
            } label: {
                Text("Send")
                    .fontWeight(.semibold)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    func send() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        viewModel.send(text: text)
        messageText = ""
    }
}

// MARK: - TIME

private extension EnquiryChatView {
    
    func timeString(from date: Date?) -> String {
        guard let date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
