import SwiftUI
import FirebaseAuth

struct BusinessHomeView: View {

    @EnvironmentObject private var authManager: AuthManager

    // MARK: - Derived
    private var businessId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if let businessId {
                    content(businessId: businessId)
                } else {
                    ProgressView("Loading business…")
                }
            }
            .navigationTitle("Business")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log out", role: .destructive) {
                        try? Auth.auth().signOut()
                        authManager.clearRole()
                    }
                }
            }
        }
    }

    // MARK: - Main Content
    private func content(businessId: String) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                staffUsageTile(businessId: businessId)   // 🔑 A9.3 monetisation surface
                menuGrid(businessId: businessId)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Business Dashboard")
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Staff Usage Tile (A9.3)
    private func staffUsageTile(businessId: String) -> some View {
        NavigationLink {
            BusinessStaffListView(businessId: businessId)
        } label: {
            HStack(spacing: 16) {

                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Staff")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Manage staff & availability")
                        .font(.headline)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Menu Grid
    private func menuGrid(businessId: String) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 20
        ) {

            NavigationLink {
                BusinessBookingsView(businessId: businessId)
            } label: {
                menuTile(title: "Bookings", icon: "calendar")
            }


            NavigationLink {
                OpeningHoursView(businessId: businessId)
            } label: {
                menuTile(title: "Opening Hours", icon: "clock")
            }

            NavigationLink {
                Text("Manage your business details")
                    .foregroundColor(.secondary)
            } label: {
                menuTile(title: "Profile", icon: "building.2")
            }

            NavigationLink {
                SettingsView()
            } label: {
                menuTile(title: "Settings", icon: "gearshape")
            }
        }
    }

    // MARK: - Tile UI
    private func menuTile(title: String, icon: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 6,
                    x: 0,
                    y: 4
                )
        )
    }
}
