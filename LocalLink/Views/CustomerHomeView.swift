import SwiftUI

struct CustomerHomeView: View {

    @EnvironmentObject private var nav: NavigationState

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                primaryAction
                secondaryActions
                settingsLink
                switchRoleButton
                legalSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("LocalLink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Change role") {
                    nav.reset()
                    nav.path.append(.startSelection)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book local services")
                .font(.largeTitle.bold())

            Text("Find trusted businesses near you and book instantly.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryAction: some View {
        NavigationLink {
            BusinessListView()
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

                Text("Browse trusted local services and book instantly")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                LinearGradient(
                    colors: [
                        Color.accentColor,
                        Color.accentColor.opacity(0.85)
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
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
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
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    private var switchRoleButton: some View {
        Button {
            nav.reset()
            nav.path.append(.startSelection)
        } label: {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.orange.opacity(0.35))
                    )
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
