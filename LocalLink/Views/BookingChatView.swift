import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingChatView: View {

    let bookingId: String
    let businessId: String
    let customerId: String
    let currentUserRole: String   // "customer" or "business"

    @State private var messages: [BookingMessage] = []
    @State private var newMessage: String = ""
    @State private var listener: ListenerRegistration?

    private let db = Firestore.firestore()
    private let repo = BookingChatRepository()

    var body: some View {

        VStack {

            ScrollViewReader { proxy in
                ScrollView {

                    LazyVStack(alignment: .leading, spacing: 10) {

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            messageInputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListening()
            resetUnreadCounter()
        }
        .onDisappear {
            stopListening()
        }
    }

    // MARK: - Input Bar

    private var messageInputBar: some View {

        HStack {

            TextField("Message…", text: $newMessage)
                .textFieldStyle(.roundedBorder)

            Button("Send") {
                send()
            }
            .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)

        }
        .padding()
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: BookingMessage) -> some View {

        let isMe = message.senderId == Auth.auth().currentUser?.uid

        return HStack {

            if isMe { Spacer() }

            Text(message.text)
                .padding()
                .background(isMe ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isMe ? .white : .primary)
                .cornerRadius(12)

            if !isMe { Spacer() }
        }
    }

    // MARK: - Firestore Listener

    private func startListening() {

        listener = db.collection("bookings")
            .document(bookingId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in

                guard let documents = snapshot?.documents else { return }

                self.messages = documents.compactMap {
                    try? $0.data(as: BookingMessage.self)
                }
            }
    }

    private func stopListening() {

        listener?.remove()
        listener = nil
    }

    // MARK: - Send Message

    private func send() {

        let trimmed = newMessage.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty, trimmed.count <= 2000 else { return }

        // Instant local message for smoother UX
        let tempMessage = BookingMessage(
            id: UUID().uuidString,
            senderId: Auth.auth().currentUser?.uid ?? "",
            senderRole: currentUserRole,
            text: trimmed,
            createdAt: Date()
        )

        messages.append(tempMessage)

        repo.sendMessage(
            bookingId: bookingId,
            businessId: businessId,
            customerId: customerId,
            text: trimmed,
            senderRole: currentUserRole
        ) { result in

            switch result {

            case .success:
                newMessage = ""

            case .failure(let error):
                print("Chat send error:", error)
            }
        }
    }

    // MARK: - Reset Unread Counter

    private func resetUnreadCounter() {

        let bookingRef = db.collection("bookings").document(bookingId)

        if currentUserRole == "customer" {

            bookingRef.updateData([
                "unreadForCustomer": 0
            ])

        } else {

            bookingRef.updateData([
                "unreadForBusiness": 0
            ])
        }
    }
}
