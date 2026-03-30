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

                // ✅ Conversion-focused headline
                Text("Start getting bookings")
                    .font(.largeTitle.bold())

                // MARK: Business Name

                VStack(alignment: .leading, spacing: 6) {

                    Text("Business name")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Business name", text: $businessName)
                        .textFieldStyle(.roundedBorder)
                }

                // MARK: Address

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

                                            Text(result.title)
                                                .font(.headline)

                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
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

                // MARK: Category

                VStack(alignment: .leading, spacing: 6) {

                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Category", selection: $selectedCategory) {

                        Text("Select category").tag(BusinessCategory?.none)

                        ForEach(BusinessCategory.allCases) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Town

                VStack(alignment: .leading, spacing: 6) {

                    Text("Town")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Town", selection: $selectedTown) {

                        Text("Select town").tag(SupportedTown?.none)

                        ForEach(SupportedTown.allCases) { town in
                            Text(town.rawValue).tag(Optional(town))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Mobile Toggle

                Toggle("Mobile business (travels to customers)", isOn: $isMobile)
                    .onChange(of: isMobile) { newValue in
                        if newValue, let selectedTown {
                            selectedServiceTowns.insert(selectedTown)
                        }
                    }

                // MARK: Service Towns

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

                // MARK: Error Message

                if let errorMessage {

                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: Create Button

                Button {

                    // ✅ Dismiss keyboard
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

    // MARK: Address Selection

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

    // MARK: Infer Town

    private func inferTown(from address: String) {

        for town in SupportedTown.allCases {
            if address.localizedCaseInsensitiveContains(town.rawValue) {
                selectedTown = town
                break
            }
        }
    }

    // MARK: Validation

    private var formIsValid: Bool {

        let baseValid =
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCategory != nil &&
        selectedTown != nil

        if isMobile {
            return baseValid && !selectedServiceTowns.isEmpty
        }

        return baseValid
    }

    // MARK: Create Business

    private func createBusiness() {

        guard formIsValid else {
            errorMessage = "Please complete all required fields."
            return
        }

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to continue."
            return
        }

        guard !user.isAnonymous else {
            errorMessage = "Please create an account to create a business."
            return
        }

        guard user.isEmailVerified else {
            user.sendEmailVerification()
            errorMessage = "Please verify your email before creating a business."
            return
        }

        guard let selectedCategory,
              let selectedTown else { return }

        isSaving = true
        errorMessage = nil

        // ✅ Prevent duplicate businesses
        db.collection("businesses")
            .whereField("ownerId", isEqualTo: user.uid)
            .limit(to: 1)
            .getDocuments { snapshot, _ in

                if snapshot?.documents.first != nil {
                    DispatchQueue.main.async {
                        isSaving = false
                        errorMessage = "You already have a business."
                    }
                    return
                }

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
}
