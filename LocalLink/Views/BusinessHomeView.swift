import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessHomeView: View {

    @StateObject private var resolver = BusinessResolverViewModel()

    var body: some View {
        Group {
            if resolver.isLoading {
                ProgressView("Loading business…")
            }
            else if !resolver.errorMessage.isEmpty {
                errorState
            }
            else if let businessId = resolver.selectedBusinessId {
                content(businessId: businessId)
            }
            else {
                ProgressView("Loading business…")
            }
        }
        .navigationTitle("Business")
        .onAppear {
            // Safe: reloading on appear keeps it correct after sign-in / switching accounts
            resolver.load()
        }
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Business not ready")
                .font(.headline)

            Text(resolver.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                resolver.load()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Main Content
    private func content(businessId: String) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection

                // Optional: shows which business is selected (useful once you add multi-business UI later)
                selectedBusinessHint

                staffUsageTile(businessId: businessId)
                menuGrid(businessId: businessId)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var selectedBusinessHint: some View {
        Group {
            if resolver.businesses.count > 1, let first = resolver.businesses.first {
                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current business")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(first.name)
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    Text("Multi-business")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.14))
                        )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
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

    // MARK: - Staff Usage Tile
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

            // ✅ Changed: go to READ profile first (then edit from there)
            NavigationLink {
                BusinessProfileView(businessId: businessId)
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

