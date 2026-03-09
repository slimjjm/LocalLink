import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingDetailView: View {

    let bookingId: String
    let currentUserRole: String   // "customer" or "business"

    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var isCancelling = false
    @State private var errorMessage: String?

    @State private var listener: ListenerRegistration?

    private let db = Firestore.firestore()
    private let bookingService = BookingService()

    var body: some View {
        VStack(spacing: 20) {

            if isLoading {
                ProgressView("Loading booking…")
            }

            else if let booking {

                details(for: booking)

                if unreadCount(for: booking) > 0 {
                    newMessageBanner(count: unreadCount(for: booking))
                }

                if booking.status == .confirmed {
                    chatButton(for: booking)
                }

                if canCancel(booking) {
                    cancelButton(for: booking)
                }
            }

            else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(AppColors.error)
            }

            else {
                Text("Booking not found")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    // MARK: - Unread

    private func unreadCount(for booking: Booking) -> Int {
        currentUserRole == "customer"
        ? booking.unreadCustomerCount
        : booking.unreadBusinessCount
    }

    private func newMessageBanner(count: Int) -> some View {
        HStack {
            Image(systemName: "message.fill")
            Text("You have \(count) new message\(count > 1 ? "s" : "")")
        }
        .font(.footnote)
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.primary.opacity(0.15))
        .foregroundColor(AppColors.primary)
        .cornerRadius(10)
    }

    // MARK: - Chat

    private func chatButton(for booking: Booking) -> some View {

        NavigationLink {
            BookingChatView(
                bookingId: booking.id ?? "",
                businessId: booking.businessId,
                customerId: booking.customerId,
                currentUserRole: currentUserRole
            )
        } label: {
            Text("Open Chat")
                .frame(maxWidth: .infinity)
        }
        .primaryButton()
    }

    // MARK: - Cancel (Option B)

    private func cancelButton(for booking: Booking) -> some View {

        Button(role: .destructive) {

            guard let id = booking.id else { return }
            isCancelling = true

            bookingService.cancelBookingAsBusiness(
                bookingId: id
            ) { result in

                DispatchQueue.main.async {
                    isCancelling = false

                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    }
                }
            }

        } label: {
            if isCancelling {
                ProgressView()
            } else {
                Text("Cancel Booking")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .tint(AppColors.error)
    }

    private func canCancel(_ booking: Booking) -> Bool {
        booking.status == .confirmed &&
        booking.startDate > Date()
    }

    // MARK: - Listener

    private func startListening() {

        listener = db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snapshot, _ in

                if let snapshot {
                    self.booking = try? snapshot.data(as: Booking.self)
                    self.isLoading = false
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Details

    private func details(for booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(booking.safeServiceName)
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)

            Divider()

            infoRow("Staff", booking.safeStaffName)
            infoRow("Customer", booking.safeCustomerName)

            infoRow(
                "Date",
                booking.startDate.formatted(date: .long, time: .omitted)
            )

            infoRow(
                "Time",
                booking.startDate.formatted(date: .omitted, time: .shortened)
            )

            infoRow("Duration", "\(booking.serviceDurationMinutes) mins")
            infoRow("Price", String(format: "£%.2f", Double(booking.price)/100))
            infoRow("Status", booking.status.rawValue.capitalized)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}
