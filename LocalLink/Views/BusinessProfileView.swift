import SwiftUI
import FirebaseFirestore

struct BusinessProfileView: View {

    let businessId: String
    @StateObject private var viewModel = BusinessProfileViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading profile…")

            } else if !viewModel.errorMessage.isEmpty {
                errorState

            } else if let business = viewModel.business {
                profileContent(business: business)

            } else {
                Text("No profile data found.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.business != nil {
                NavigationLink("Edit") {
                    BusinessProfileEditView(businessId: businessId)
                }
            }
        }
        .onAppear {
            viewModel.load(businessId: businessId)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Couldn’t load profile")
                .font(.headline)

            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                viewModel.load(businessId: businessId)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Content

    private func profileContent(business: Business) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard(business: business)
                detailsCard(business: business)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func headerCard(business: Business) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(business.businessName)
                .font(.title2.bold())

            if let address = business.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            statusPill(isActive: business.isActive)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func detailsCard(business: Business) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Details")
                .font(.headline)

            keyValueRow(title: "Business name", value: business.businessName)
            keyValueRow(title: "Address", value: business.address ?? "—")

            Divider().padding(.vertical, 6)

            Text("""
Contact details are stored securely.
Customers book appointments inside the app.
""")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    private func keyValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)

            Spacer()
        }
    }

    private func statusPill(isActive: Bool) -> some View {
        Text(isActive ? "Active" : "Paused")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isActive
                        ? Color.green.opacity(0.15)
                        : Color.orange.opacity(0.15)
                )
            )
    }
}
