import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
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
    private let functions = Functions.functions(region: "us-central1")

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                Text("Start getting bookings")
                    .font(.largeTitle.bold())

             
                Button {
                    authManager.setRole(.customer)
                    nav.reset()
                    nav.path.append(.customerHome)
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Continue as customer")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Business name")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Business name", text: $businessName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {

                    Text("Business address")
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                                            Text(result.title).font(.headline)
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
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag(BusinessCategory?.none)
                        ForEach(BusinessCategory.allCases) {
                            Text($0.rawValue).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Town")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Town", selection: $selectedTown) {
                        Text("Select town").tag(SupportedTown?.none)
                        ForEach(SupportedTown.allCases) {
                            Text($0.rawValue).tag(Optional($0))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Mobile business (travels to customers)", isOn: $isMobile)
                    .onChange(of: isMobile) { newValue in
                        if newValue, let selectedTown {
                            selectedServiceTowns.insert(selectedTown)
                        }
                    }

                if isMobile {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service towns").font(.headline)

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

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    private func inferTown(from address: String) {
        for town in SupportedTown.allCases {
            if address.localizedCaseInsensitiveContains(town.rawValue) {
                selectedTown = town
                break
            }
        }
    }

    private var formIsValid: Bool {

        let baseValid =
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCategory != nil &&
        selectedTown != nil

        return isMobile ? baseValid && !selectedServiceTowns.isEmpty : baseValid
    }

    // MARK: CREATE BUSINESS + STRIPE CONNECT

    private func createBusiness() {

        guard formIsValid else {
            errorMessage = "Please complete all required fields."
            return
        }

        guard let user = Auth.auth().currentUser, !user.isAnonymous else {
            errorMessage = "Please sign in."
            return
        }

        guard user.isEmailVerified else {
            user.sendEmailVerification()
            errorMessage = "Verify your email first."
            return
        }

        guard let selectedCategory, let selectedTown else { return }

        isSaving = true
        errorMessage = nil

        let docRef = db.collection("businesses").document()
        let businessId = docRef.documentID

        let baseTown = selectedTown.rawValue
        let serviceTownValues = isMobile
        ? selectedServiceTowns.map { $0.rawValue }
        : [baseTown]

        let data: [String: Any] = [
            "businessName": businessName,
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
            "verified": false
        ]

        docRef.setData(data) { error in

            if let error {
                self.errorMessage = error.localizedDescription
                self.isSaving = false
                return
            }

            // STEP 1 — Create Stripe account
            functions.httpsCallable("createConnectedAccount").call { result, error in

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isSaving = false
                    return
                }

                guard let data = result?.data as? [String: Any],
                      let accountId = data["accountId"] as? String else {
                    self.errorMessage = "Stripe account failed"
                    self.isSaving = false
                    return
                }

                // STEP 2 — Save accountId
                docRef.updateData([
                    "stripeAccountId": accountId
                ])

                // STEP 3 — Get onboarding link
                functions.httpsCallable("createAccountLink")
                    .call(["accountId": accountId]) { result, error in

                        self.isSaving = false

                        if let error {
                            self.errorMessage = error.localizedDescription
                            return
                        }

                        guard let data = result?.data as? [String: Any],
                              let urlString = data["url"] as? String,
                              let url = URL(string: urlString) else {
                            self.errorMessage = "Onboarding failed"
                            return
                        }

                        UIApplication.shared.open(url)

                        self.authManager.setRole(.business)
                        self.nav.reset()
                    }
            }
        }
    }
}
