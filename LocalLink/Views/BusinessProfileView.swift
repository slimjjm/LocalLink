import SwiftUI
import FirebaseFirestore

struct BusinessProfileView: View {

    let businessId: String
    @StateObject private var viewModel = BusinessProfileViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading profile…")
            }
            else if !viewModel.errorMessage.isEmpty {
                errorState
            }
            else if let business = viewModel.business {
                profileContent(business: business)
            }
            else {
                Text("No profile data found.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Business Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.business != nil {
                    NavigationLink("Edit") {
                        BusinessProfileEditView(businessId: businessId)
                    }
                }
            }
        }
        .onAppear {
            viewModel.load(businessId: businessId)
        }
    }

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
                .padding(.horizontal)

            Button("Retry") {
                viewModel.load(businessId: businessId)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func profileContent(business: BusinessProfileModel) -> some View {
        ScrollView {
            VStack(spacing: 18) {

                headerCard(business: business)

                detailsCard(business: business)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func headerCard(business: BusinessProfileModel) -> some View {
        HStack(spacing: 14) {

            LogoView(urlString: business.logoURL)

            VStack(alignment: .leading, spacing: 6) {

                HStack(spacing: 8) {
                    Text(business.name.isEmpty ? "Unnamed Business" : business.name)
                        .font(.title2.bold())
                        .lineLimit(2)

                    if business.isPro {
                        Text("PRO")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }

                if !business.openingHours.isEmpty {
                    Text(business.openingHours)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    statusPill(isActive: business.isActive)

                    if business.isPro == false {
                        Text("Chat is Pro-only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func detailsCard(business: BusinessProfileModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Details")
                .font(.headline)

            keyValueRow(title: "Name", value: business.name)
            keyValueRow(title: "Contact number", value: business.contactNumber)
            keyValueRow(title: "Latitude", value: business.latitude != nil ? String(business.latitude!) : "")
            keyValueRow(title: "Longitude", value: business.longitude != nil ? String(business.longitude!) : "")

            Divider().padding(.vertical, 6)

            Text("Notes")
                .font(.headline)

            Text("Contact details are stored but not shown to customers in v1, to keep bookings inside the app. This protects your revenue model.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func statusPill(isActive: Bool) -> some View {
        Text(isActive ? "Active" : "Paused")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            )
    }
}

// MARK: - View Model + Model

@MainActor
final class BusinessProfileViewModel: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""
    @Published var business: BusinessProfileModel? = nil

    private let db = Firestore.firestore()

    func load(businessId: String) {
        isLoading = true
        errorMessage = ""
        business = nil

        db.collection("businesses").document(businessId).getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.isLoading = false
                self.errorMessage = "Failed to load business profile. \(error.localizedDescription)"
                return
            }

            guard let data = snapshot?.data() else {
                self.isLoading = false
                self.errorMessage = "Business document not found."
                return
            }

            let model = BusinessProfileModel(
                name: data["name"] as? String ?? "",
                openingHours: data["openingHours"] as? String ?? "",
                logoURL: data["logoURL"] as? String ?? "",
                contactNumber: data["contactNumber"] as? String ?? "",
                isActive: data["isActive"] as? Bool ?? true,
                isPro: data["isPro"] as? Bool ?? false,
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double
            )

            self.business = model
            self.isLoading = false
        }
    }
}

struct BusinessProfileModel {
    let name: String
    let openingHours: String
    let logoURL: String
    let contactNumber: String
    let isActive: Bool
    let isPro: Bool
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Logo View

private struct LogoView: View {
    let urlString: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemFill))

            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    @unknown default:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 74, height: 74)
    }
}
