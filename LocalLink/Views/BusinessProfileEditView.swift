import SwiftUI

struct BusinessProfileEditView: View {

    let businessId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BusinessProfileEditViewModel()

    var body: some View {
        Form {

            Section("Business details") {

                TextField("Business name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)

                TextField("Contact number (stored, not public)", text: $viewModel.contactNumber)
                    .keyboardType(.phonePad)

                Toggle("Business is active", isOn: $viewModel.isActive)
            }

            Section("Service area") {

                TextField(
                    "e.g. Burntwood, Chasetown, Lichfield",
                    text: $viewModel.serviceArea
                )
                .textInputAutocapitalization(.words)

                Text("This is shown to customers so they know where you operate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !viewModel.errorMessage.isEmpty {
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
            }

            Section {
                Button("Save changes") {
                    viewModel.save(businessId: businessId) {
                        dismiss()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            if viewModel.isSaving {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.load(businessId: businessId)
        }
    }
}
