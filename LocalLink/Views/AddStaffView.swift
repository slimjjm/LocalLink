import SwiftUI
import FirebaseFirestore

struct AddStaffView: View {

    let businessId: String
    let onUnlockTapped: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var restrictionMode = false

    @State private var entitlementListener: ListenerRegistration?

    private let db = Firestore.firestore()
    private let repo = StaffRepository()

    var body: some View {

        VStack(spacing: 24) {

            if restrictionMode {
                restrictionBanner
            }

            VStack(spacing: 12) {

                Text("Staff Member")
                    .font(.headline)
                    .foregroundColor(AppColors.charcoal)

                TextField("Staff name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                Task { await createStaff() }
            } label: {

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Add Staff Member")
                        .frame(maxWidth: .infinity)
                }
            }
            .primaryButton()
            .disabled(isLoading || restrictionMode || name.trimmingCharacters(in: .whitespaces).isEmpty)

            Button {
                onUnlockTapped()
            } label: {
                Text("Unlock more staff seats")
                    .font(.footnote)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(AppColors.error)
                    .font(.footnote)
            }

            Spacer()
        }
        .padding()
        .background(AppColors.background)
        .navigationTitle("Add Staff")
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    private var restrictionBanner: some View {

        Text("Account restricted due to unresolved billing. Staff expansion is disabled until payment is resolved.")
            .font(.footnote)
            .foregroundColor(AppColors.error)
            .multilineTextAlignment(.center)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
    }

    // MARK: Firestore Listener

    private func startListening() {

        let entRef = db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")

        entitlementListener?.remove()

        entitlementListener = entRef.addSnapshotListener { snap, _ in
            DispatchQueue.main.async {
                if let data = snap?.data() {
                    restrictionMode = data["restrictionMode"] as? Bool ?? false
                }
            }
        }
    }

    private func stopListening() {
        entitlementListener?.remove()
        entitlementListener = nil
    }

    // MARK: Create Staff

    private func createStaff() async {

        errorMessage = nil
        isLoading = true

        do {

            _ = try await repo.createStaff(
                businessId: businessId,
                name: name
            )

            dismiss()

        } catch {

            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
