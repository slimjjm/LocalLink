import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingChatView: View {

    let bookingId: String
    let businessId: String
    let customerId: String
    let currentUserRole: String

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var messages: [BookingMessage] = []
    @State private var newMessage: String = ""
    @State private var listener: ListenerRegistration?
    @State private var bookingListener: ListenerRegistration?
    @State private var isNearBottom: Bool = true
    @State private var booking: Booking?
    @State private var isActiveChatSet = false
    @State private var showLoginAlert = false

    private let db = Firestore.firestore()
    private let repo = BookingChatRepository()

    private var isGuest: Bool {
        Auth.auth().currentUser?.isAnonymous == true
    }

    var body: some View {

        VStack {

            ScrollViewReader { proxy in
                ScrollView {

                    LazyVStack(spacing: 12) {

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    guard isNearBottom else { return }

                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // ✅ INPUT AREA SWITCHES BASED ON AUTH
            if isGuest {
                guestCTA
            } else {
                messageInputBar
            }
        }
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            // 🚫 Don’t even start listeners for guest
            if isGuest {
                showLoginAlert = true
                return
            }

            startListening()
            startBookingListener()
            markAsRead()
            setActiveChat()
        }
        .onDisappear {
            stopListening()
            clearActiveChat()
        }
        .alert("Sign in required", isPresented: $showLoginAlert) {
            Button("Sign in") {
                goToLogin()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need an account to view and send messages.")
        }
    }
}

//
// MARK: - Title
//

private extension BookingChatView {

    var chatTitle: String {
        guard let booking else { return "Chat" }

        return currentUserRole == "customer"
            ? (booking.businessName ?? "Business")
            : (booking.customerName ?? "Customer")
    }
}

//
// MARK: - Guest CTA
//

private extension BookingChatView {

    var guestCTA: some View {
        VStack(spacing: 12) {
            Text("Sign in to view and send messages")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                goToLogin()
            } label: {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }

    func goToLogin() {
        authManager.requireFullLogin()

        // ✅ Save where to return
        nav.pendingRoute = AppRoute.bookingChat(bookingId: bookingId)

        nav.reset()
        nav.path.append(AppRoute.authEntry)
    }
    }

//
// MARK: - Input
//

private extension BookingChatView {

    var messageInputBar: some View {
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
}

//
// MARK: - Message Bubble
//

private extension BookingChatView {

    func messageBubble(_ message: BookingMessage) -> some View {

        let isMe = message.senderId == Auth.auth().currentUser?.uid

        return HStack {

            if isMe { Spacer() }

            VStack(alignment: .leading, spacing: 6) {

                Text(message.text)
                    .padding()
                    .background(isMe ? AppColors.primary : Color(.secondarySystemBackground))
                    .foregroundColor(isMe ? .white : .primary)
                    .cornerRadius(12)
                    .frame(maxWidth: 260, alignment: isMe ? .trailing : .leading)

                HStack {
                    if isMe { Spacer() }

                    Text(timeAgoString(from: message.createdAt ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !isMe { Spacer() }
                }

                if isMe {
                    HStack {
                        Spacer()
                        Text("Sent")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !isMe { Spacer() }
        }
    }
}

//
// MARK: - Time
//

private extension BookingChatView {

    func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 { return "Now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 172800 { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

//
// MARK: - Firestore
//

private extension BookingChatView {

    func startListening() {
        listener = db.collection("bookings")
            .document(bookingId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in

                guard let docs = snapshot?.documents else { return }

                let fetched = docs.compactMap {
                    try? $0.data(as: BookingMessage.self)
                }

                DispatchQueue.main.async {
                    self.messages = fetched.sorted {
                        ($0.createdAt ?? Date()) < ($1.createdAt ?? Date())
                    }
                }
            }
    }

    func startBookingListener() {
        bookingListener = db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                self.booking = try? snapshot.data(as: Booking.self)
            }
    }

    func stopListening() {
        listener?.remove()
        bookingListener?.remove()
        listener = nil
        bookingListener = nil
    }
}

//
// MARK: - Send
//

private extension BookingChatView {

    func send() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard let user = Auth.auth().currentUser else { return }

        // 🚫 BLOCK GUEST SEND
        if user.isAnonymous {
            showLoginAlert = true
            return
        }

        let uid = user.uid

        let tempMessage = BookingMessage(
            id: UUID().uuidString,
            senderId: uid,
            senderRole: currentUserRole,
            text: trimmed,
            createdAt: Date()
        )

        messages.append(tempMessage)
        newMessage = ""

        guard let booking else { return }

        repo.sendMessage(
            bookingId: bookingId,
            businessId: booking.businessId,
            customerId: booking.customerId,
            text: trimmed,
            senderRole: currentUserRole
        ) { result in
            if case .failure(let error) = result {
                print("❌ Send failed:", error.localizedDescription)
            }
        }
    }
}

//
// MARK: - Read
//

private extension BookingChatView {

    func markAsRead() {
        let ref = db.collection("bookings").document(bookingId)

        if currentUserRole == "customer" {
            ref.updateData(["unreadForCustomer": 0])
        } else {
            ref.updateData(["unreadForBusiness": 0])
        }
    }
}

//
// MARK: - Active Chat
//

private extension BookingChatView {

    func setActiveChat() {
        guard let user = Auth.auth().currentUser else { return }
        if user.isAnonymous { return }

        let uid = user.uid
        guard !isActiveChatSet else { return }

        db.collection("users")
            .document(uid)
            .setData([
                "activeChatBookingId": bookingId
            ], merge: true)

        isActiveChatSet = true
    }

    func clearActiveChat() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .setData([
                "activeChatBookingId": FieldValue.delete()
            ], merge: true)

        isActiveChatSet = false
    }
}
