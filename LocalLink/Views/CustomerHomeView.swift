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

                primaryAction

                inboxCard

                if unreadVM.totalUnread > 0 {
                    unreadBanner
                }

                secondaryActions

                switchRoleSection
                legalSection
            }
            .padding(16)
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
            }
        }

        .onAppear {
            unreadVM.startListening(role: "customer", businessId: nil)
        }
        .onDisappear {
            unreadVM.stopListening()
        }
    }
}

// MARK: - HEADER

private extension CustomerHomeView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("Find trusted local services")
                .font(.title2.bold())
                .foregroundColor(AppColors.charcoal)

            Text("Book reliable professionals near you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - PRIMARY CTA

private extension CustomerHomeView {

    var primaryAction: some View {
        NavigationLink {
            CustomerBusinessSearchView()
        } label: {

            VStack(alignment: .leading, spacing: 10) {

                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Find a service")
                }
                .font(.headline)

                Text("Cleaners, dog groomers and more near you")
                    .font(.subheadline)
                    .opacity(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        }
    }
}

// MARK: - INBOX

private extension CustomerHomeView {

    var inboxCard: some View {
        NavigationLink {
            InboxView()
        } label: {

            HStack(spacing: 14) {

                icon("bubble.left.and.bubble.right.fill")

                VStack(alignment: .leading, spacing: 4) {

                    Text("Inbox")
                        .font(.subheadline.weight(.semibold))

                    Text(unreadVM.totalUnread > 0
                         ? "\(unreadVM.totalUnread) unread message\(unreadVM.totalUnread > 1 ? "s" : "")"
                         : "Messages and updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if unreadVM.totalUnread > 0 {
                    badge(unreadVM.totalUnread)
                }

                chevron
            }
            .modifier(CardStyle(highlight: unreadVM.totalUnread > 0))
        }
    }
}

// MARK: - UNREAD BANNER

private extension CustomerHomeView {

    var unreadBanner: some View {
        NavigationLink {
            CustomerBookingsView()
        } label: {

            HStack {
                Image(systemName: "message.fill")
                Text("\(unreadVM.totalUnread) unread messages")
                Spacer()
                chevron
            }
            .font(.footnote.weight(.semibold))
            .padding()
            .background(AppColors.primary.opacity(0.12))
            .foregroundColor(AppColors.primary)
            .cornerRadius(14)
        }
    }
}

// MARK: - SECONDARY

private extension CustomerHomeView {

    var secondaryActions: some View {
        VStack(spacing: 12) {

            NavigationLink {
                CustomerBookingsView()
            } label: {
                secondaryCard(
                    title: "Your bookings",
                    subtitle: "Upcoming & past appointments",
                    icon: "calendar"
                )
            }

            NavigationLink {
                SettingsView()
            } label: {
                secondaryCard(
                    title: "Settings",
                    subtitle: "Account & preferences",
                    icon: "gearshape"
                )
            }
        }
    }
}

// MARK: - SWITCH ROLE

private extension CustomerHomeView {

    var switchRoleSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Divider().padding(.vertical, 8)

            Text("Are you a service provider?")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                authManager.setRole(.business)
            } label: {
                HStack {
                    Image(systemName: "briefcase.fill")
                    Text("Switch to business account")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - LEGAL

private extension CustomerHomeView {

    var legalSection: some View {
        VStack(spacing: 6) {

            Divider().padding(.vertical, 8)

            HStack {
                Link("Privacy", destination: URL(string: "https://locallinkapp.co.uk/privacy")!)
                Link("Terms", destination: URL(string: "https://locallinkapp.co.uk/terms")!)
            }
            .font(.footnote)
            .foregroundColor(.secondary)

            Link("Contact", destination: URL(string: "https://locallinkapp.co.uk/contact")!)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - COMPONENTS

private extension CustomerHomeView {

    func secondaryCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {

            self.icon(icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }

            Spacer()
            chevron
        }
        .modifier(CardStyle())
    }

    func icon(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.12))
                .frame(width: 40, height: 40)

            Image(systemName: name)
                .foregroundColor(AppColors.primary)
        }
    }

    func badge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.bold())
            .padding(8)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .clipShape(Circle())
    }

    var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
    }
}

