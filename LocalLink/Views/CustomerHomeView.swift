import SwiftUI

struct CustomerHomeView: View {

    @EnvironmentObject private var authManager: AuthManager

    @EnvironmentObject private var nav: NavigationState
    @StateObject private var unreadVM = ChatUnreadViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                headerSection

                // 🔔 UNREAD BANNER (Tappable)
                if unreadVM.totalUnread > 0 {
                    NavigationLink {
                        CustomerBookingsView()
                    } label: {
                        HStack(spacing: 10) {
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
                        .background(AppColors.primary.opacity(0.15))
                        .foregroundColor(AppColors.primary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                primaryAction
                secondaryActions
                settingsLink
                switchRoleButton
                legalSection
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("LocalLink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Change role") {
                    authManager.clearRole()
                    nav.reset()
                }
            }
        }
        .onAppear {
            unreadVM.startListening(role: "customer")
        }
        .onDisappear {
            unreadVM.stopListening()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book local services")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)

            Text("Find trusted businesses near you and book instantly.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryAction: some View {
        NavigationLink {
            CustomerBusinessSearchView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {

                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }

                Text("Find a business")
                    .font(.title3.bold())

                Text("Search by category and town to book instantly")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                LinearGradient(
                    colors: [
                        AppColors.primary,
                        AppColors.primary.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(20)
            .shadow(radius: 10, y: 6)
        }
    }

    private var secondaryActions: some View {
        VStack(spacing: 14) {
            NavigationLink {
                CustomerBookingsView()
            } label: {
                secondaryTile(
                    icon: "calendar",
                    title: "My bookings",
                    subtitle: "View upcoming and past appointments"
                )
            }
        }
    }

    private func secondaryTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(AppColors.primary.opacity(0.15))
                .foregroundColor(AppColors.primary)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var settingsLink: some View {
        NavigationLink {
            SettingsView()
        } label: {
            HStack {
                Image(systemName: "gearshape")
                Text("Settings")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            .cornerRadius(16)
        }
    }

    private var switchRoleButton: some View {
        Button(action: {
            nav.reset()
        }) {
            HStack(spacing: 14) {

                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Back to welcome")
                        .font(.headline)

                    Text("Switch between customer and business mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var legalSection: some View {
        VStack(spacing: 6) {
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
        .padding(.top, 24)
    }
}
