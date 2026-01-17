import SwiftUI
import FirebaseFirestoreSwift

struct AddStaffView: View {

    // MARK: - Inputs
    let businessId: String
    let onStaffAdded: () -> Void = {}

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var name = ""
    @State private var skillsText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showUpgradePrompt = false

    // MARK: - Services
    private let staffRepo = StaffRepository()
    private let staffLimitService = StaffLimitService()

    // MARK: - View
    var body: some View {
        Form {

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Section("Staff Details") {
                TextField("Name", text: $name)

                TextField("Skills (comma separated)", text: $skillsText)
                    .textInputAutocapitalization(.sentences)
            }

            Section {
                Button {
                    attemptAddStaff()
                } label: {
                    Text(isSaving ? "Saving…" : "Save Staff")
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Add Staff")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Staff limit reached", isPresented: $showUpgradePrompt) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You’ve reached your current staff limit. Unlock an additional staff slot to add more team members.")
        }
    }

    // MARK: - Flow
    private func attemptAddStaff() {
        isSaving = true
        errorMessage = nil

        staffLimitService.fetchLimits(businessId: businessId) { used, max in
            DispatchQueue.main.async {
                if used < max {
                    saveStaff()
                } else {
                    isSaving = false
                    showUpgradePrompt = true
                }
            }
        }
    }

    // MARK: - Save
    private func saveStaff() {
        let cleanedName =
            name.trimmingCharacters(in: .whitespacesAndNewlines)

        let skills =
            skillsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        let staff = Staff(
            id: nil,
            name: cleanedName,
            isActive: true,
            skills: skills
        )


        staffRepo.createStaff(
            businessId: businessId,
            staff: staff
        ) { result in
            DispatchQueue.main.async {
                isSaving = false

                switch result {
                case .success:
                    onStaffAdded()
                    dismiss()

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

