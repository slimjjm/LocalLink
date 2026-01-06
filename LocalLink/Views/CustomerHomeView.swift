import SwiftUI

struct CustomerHomeView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                headerSection
                primaryAction
                secondaryActions
                settingsLink
                legalSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("LocalLink")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book local services")
                .font(.largeTitle.bold())

            Text("Find trusted businesses near you and book instantly.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Primary CTA

    private var primaryAction: some View {
        NavigationLink {
            BusinessListView()
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Find a business")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
    }

    // MARK: - Secondary actions

    private var secondaryActions: some View {
        NavigationLink {
            CustomerBookingsView()
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text("My bookings")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Settings

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
            .cornerRadius(14)
        }
    }

    // MARK: - Legal

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

