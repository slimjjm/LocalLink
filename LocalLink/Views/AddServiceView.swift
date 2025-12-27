import SwiftUI
import FirebaseFirestore

struct AddServiceView: View {
    @Environment(\.dismiss) var dismiss

    let businessId: String

    // Form fields
    @State private var name = ""
    @State private var details = ""
    @State private var price = ""
    @State private var durationMinutes = ""

    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            // SERVICE INFO
            Section("Service Info") {
                TextField("Name", text: $name)

                TextField("Details", text: $details, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Price (£)", text: $price)
                    .keyboardType(.decimalPad)

                TextField("Duration (minutes)", text: $durationMinutes)
                    .keyboardType(.numberPad)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            // SAVE BUTTON
            Button {
                saveService()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save Service")
                }
            }
            .disabled(name.isEmpty || price.isEmpty || durationMinutes.isEmpty)
        }
        .navigationTitle("Add Service")
    }

    // MARK: - SAVE FUNCTION
    private func saveService() {
        guard let priceValue = Double(price) else {
            errorMessage = "Enter a valid price."
            return
        }

        guard let durationValue = Int(durationMinutes) else {
            errorMessage = "Enter a valid duration."
            return
        }

        isSaving = true
        errorMessage = ""

        let db = Firestore.firestore()

        let data: [String: Any] = [
            "name": name,
            "details": details,
            "price": priceValue,
            "durationMinutes": durationValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .addDocument(data: data) { error in
                isSaving = false
                if let error = error {
                    errorMessage = "Failed: \(error.localizedDescription)"
                } else {
                    dismiss()
                }
            }
    }
}
