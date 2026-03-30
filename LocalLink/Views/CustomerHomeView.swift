import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CustomerHomeView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState

    @StateObject private var unreadVM = ChatUnreadViewModel()

    var body: some View {

        ScrollView {
            VStack(spacing: 24) {

                headerSection

                // 🔥 NEW — CHAT SECTION
                if !unreadVM.recentChats.isEmpty {
                    chatSection
                }

                if unreadVM.totalUnread > 0 {
                    unreadBanner
                }

                primaryAction
                secondaryActions
                switchRoleSection
                legalSection
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("LocalLink")
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    authManager.clearRole()
                    nav.reset()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Switch account type")
            }
        }

        .onAppear {
            unreadVM.startListening(
                role: "customer",
                businessId: nil
            )
        }

        .onDisappear {
            unreadVM.stopListening()
        }
    }
}

// MARK: - Sections

private extension CustomerHomeView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Find trusted local services")
                .font(.title2.weight(.semibold))
                .foregroundColor(AppColors.charcoal)

            Text("Book reliable professionals near you, quickly and with confidence.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 🔥 NEW — CHAT SECTION

    var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Messages")
                .font(.headline)

            VStack(spacing: 10) {

                ForEach(unreadVM.recentChats.prefix(3)) { chat in

                    NavigationLink {
                        BookingChatView(
                            bookingId: chat.bookingId,
                            businessId: "", // not needed for chat UI now
                            customerId: "",
                            currentUserRole: "customer"
                        )
                    } label: {
                        chatRow(chat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // 🔥 NEW — CHAT ROW

    func chatRow(_ chat: ChatPreview) -> some View {
        let isUnread = chat.unreadCount > 0

        return HStack(spacing: 12) {

            // Icon
            Circle()
                .fill(AppColors.primary.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "message.fill")
                        .foregroundColor(AppColors.primary)
                )

            // Text content
            VStack(alignment: .leading, spacing: 4) {

                HStack {
                    Text(chat.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.charcoal)

                    Spacer()

                    Text(timeAgoString(from: chat.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(chat.lastMessage)
                    .font(isUnread ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundColor(isUnread ? AppColors.charcoal : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Unread badge
            if isUnread {
                Text("\(chat.unreadCount)")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            // Chevron (navigation hint)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            Group {
                if isUnread {
                    AppColors.primary.opacity(0.05)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
        )
        .cornerRadius(14)
    }
    // MARK: Existing sections (unchanged)

    var unreadBanner: some View {
        NavigationLink {
            CustomerBookingsView()
        } label: {
            HStack(spacing: 12) {

                Image(systemName: "message.fill")

                Text("You have \(unreadVM.totalUnread) unread message\(unreadVM.totalUnread > 1 ? "s" : "")")
                    .lineLimit(2)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
            .font(.footnote.weight(.semibold))
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.primary.opacity(0.12))
            .foregroundColor(AppColors.primary)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    var primaryAction: some View {
        NavigationLink {
            CustomerBusinessSearchView()
        } label: {

            VStack(alignment: .leading, spacing: 10) {

                Text("Find a service")
                    .font(.headline)

                Text("Browse cleaners, dog groomers and more in your area")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }

    var secondaryActions: some View {
        VStack(spacing: 12) {

            NavigationLink {
                CustomerBookingsView()
            } label: {
                secondaryCard(
                    title: "Your bookings",
                    subtitle: "View upcoming and past appointments",
                    icon: "calendar"
                )
            }

            NavigationLink {
                SettingsView()
            } label: {
                secondaryCard(
                    title: "Settings",
                    subtitle: "Manage your account and preferences",
                    icon: "gearshape"
                )
            }
        }
    }

    var switchRoleSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Divider().padding(.vertical, 8)

            Text("Are you a service provider?")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                NotificationCenter.default.post(name: .didSelectRole, object: nil)
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Switch to business account")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            }
        }
    }

    var legalSection: some View {
        VStack(spacing: 6) {

            Divider().padding(.vertical, 8)

            HStack(spacing: 12) {
                Link("Privacy Policy", destination: URL(string: "https://locallinkapp.co.uk/privacy")!)
                Link("Terms", destination: URL(string: "https://locallinkapp.co.uk/terms")!)
            }
            .font(.footnote)
            .foregroundColor(.secondary)

            Link("Contact us", destination: URL(string: "https://locallinkapp.co.uk/contact")!)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    func secondaryCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {

            Image(systemName: icon)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

private func timeAgoString(from date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    
    if seconds < 60 {
        return "Now"
    } else if seconds < 3600 {
        return "\(seconds / 60)m"
    } else if seconds < 86400 {
        return "\(seconds / 3600)h"
    } else if seconds < 172800 {
        return "Yesterday"
    } else {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

