import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

struct BusinessOnboardingView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState

    @State private var businessName = ""
    @State private var address = ""
    @State private var selectedCategory: BusinessCategory?
    @State private var selectedTown: SupportedTown?

    @State private var isMobile = false
    @State private var selectedServiceTowns: Set<SupportedTown> = []

    @State private var latitude: Double?
    @State private var longitude: Double?

    @State private var isSaving = false
    @State private var errorMessage: String?

    @StateObject private var addressSearch = AddressSearchViewModel()

    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                Text("Create your business")
                    .font(.largeTitle.bold())

                // MARK: - Business Name

                TextField("Business name", text: $businessName)
                    .textFieldStyle(.roundedBorder)

                // MARK: - Address with Autocomplete

                VStack(alignment: .leading, spacing: 6) {

                    TextField("Business address", text: $address)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: address) { newValue in
                            addressSearch.update(query: newValue)
                        }

                    if !addressSearch.results.isEmpty && !address.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(addressSearch.results) { result in
                                    Button {
                                        selectAddress(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(.headline)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: addressSearch.results.count)
                    }
                }

                // MARK: - Category

                Picker("Category", selection: $selectedCategory) {
                    Text("Select category").tag(BusinessCategory?.none)
                    ForEach(BusinessCategory.allCases) { category in
                        Text(category.rawValue).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)

                // MARK: - Base Town

                Picker("Town", selection: $selectedTown) {
                    Text("Select town").tag(SupportedTown?.none)
                    ForEach(SupportedTown.allCases) { town in
                        Text(town.rawValue).tag(Optional(town))
                    }
                }
                .pickerStyle(.menu)

                // MARK: - Mobile Toggle

                Toggle("Mobile business (travels to customers)", isOn: $isMobile)

                // MARK: - Multi Town Selection

                if isMobile {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service towns")
                            .font(.headline)

                        ForEach(SupportedTown.allCases) { town in
                            MultipleSelectionRow(
                                title: town.rawValue,
                                isSelected: selectedServiceTowns.contains(town)
                            ) {
                                if selectedServiceTowns.contains(town) {
                                    selectedServiceTowns.remove(town)
                                } else {
                                    selectedServiceTowns.insert(town)
                                }
                            }
                        }
                    }
                }

                // MARK: - Error

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Create Button

                Button {
                    createBusiness()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Create business")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!formIsValid || isSaving)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Business setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Address Selection

    private func selectAddress(_ result: AddressResult) {

        address = "\(result.title), \(result.subtitle)"
        addressSearch.clear()

        Task {
            if let coordinate = await addressSearch.resolveCoordinate(for: result) {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
            }

            inferTown(from: address)
        }
    }

    // MARK: - Infer Town

    private func inferTown(from address: String) {

        for town in SupportedTown.allCases {
            if address.localizedCaseInsensitiveContains(town.rawValue) {
                selectedTown = town
                break
            }
        }
    }

    // MARK: - Validation

    private var formIsValid: Bool {

        let baseValid =
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedCategory != nil
        && selectedTown != nil

        if isMobile {
            return baseValid && !selectedServiceTowns.isEmpty
        }

        return baseValid
    }

    // MARK: - Create Business

    private func createBusiness() {

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to continue."
            return
        }

        if user.isAnonymous {
            errorMessage = "Please create an account to create a business."
            return
        }

        if !user.isEmailVerified {
            user.sendEmailVerification()
            errorMessage = "Please verify your email before creating a business."
            return
        }

        guard let selectedCategory,
              let selectedTown else {
            errorMessage = "Please complete all required fields."
            return
        }

        isSaving = true
        errorMessage = nil

        let baseTown = selectedTown.rawValue

        let serviceTownValues: [String] =
            isMobile
            ? selectedServiceTowns.map { $0.rawValue }
            : [baseTown]

        let data: [String: Any] = [
            "businessName": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": address,
            "ownerId": user.uid,
            "createdAt": FieldValue.serverTimestamp(),

            "town": baseTown,
            "category": selectedCategory.rawValue,

            "isMobile": isMobile,
            "serviceTowns": serviceTownValues,

            "latitude": latitude ?? NSNull(),
            "longitude": longitude ?? NSNull(),

            "isActive": true,
            "verified": false,

            "staffSlotsAllowed": 1,
            "staffSlotsPurchased": 0
        ]

        db.collection("businesses").addDocument(data: data) { error in
            DispatchQueue.main.async {
                isSaving = false

                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    authManager.setRole(.business)
                    nav.reset()
                    nav.path.append(.businessHome)
                }
            }
        }
    }
}
