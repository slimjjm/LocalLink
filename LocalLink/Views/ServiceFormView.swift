import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ServiceFormView: View {

    @Environment(\.dismiss) private var dismiss

    let businessId: String
    let existingService: BusinessService?   // nil = Add, non-nil = Edit

    // MARK: - Form Fields

    @State private var name = ""
    @State private var details = ""
    @State private var priceText = ""

    // 🔥 NEW duration system
    @State private var durationHours = 1
    @State private var durationMinutesPart = 0

    @State private var isActive = true

    // UI State
    @State private var localError = ""
    @State private var showDeleteConfirm = false
    @State private var isSaving = false

    private let db = Firestore.firestore()

    var body: some View {
        Form {

            // MARK: - DELETE (EDIT MODE ONLY)

            if existingService != nil {
                Section {
                    Button("Delete Service", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }

            // MARK: - SERVICE INFO

            Section("Service Info") {

                TextField("Name", text: $name)

                TextField("Details (optional)", text: $details)
                    .lineLimit(3)

                TextField("Price (£)", text: $priceText)
                    .keyboardType(.decimalPad)

                Toggle("Active", isOn: $isActive)
            }

            // MARK: - DURATION (🔥 KEY UPGRADE)

            Section("Duration") {

                DurationPickerRow(
                    hours: $durationHours,
                    minutes: $durationMinutesPart
                )

                Text("\(durationHours)h \(durationMinutesPart)m total")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // MARK: - ERROR

            if !localError.isEmpty {
                Text(localError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // MARK: - SAVE BUTTON

            Button(existingService == nil ? "Add Service" : "Save Changes") {
                saveTapped()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
            .padding(.vertical)
        }
        .navigationTitle(existingService == nil ? "Add Service" : "Edit Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExistingIfNeeded)
        .alert("Delete service?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteTapped()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the service.")
        }
    }

    // MARK: - PRESET BUTTON

    private func presetButton(_ title: String, _ h: Int, _ m: Int) -> some View {
        Button {
            durationHours = h
            durationMinutesPart = m
        } label: {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
        }
    }

    // MARK: - COMPUTED DURATION

    private var totalDurationMinutes: Int {
        (durationHours * 60) + durationMinutesPart
    }

    // MARK: - LOAD EXISTING

    private func loadExistingIfNeeded() {
        guard let service = existingService else { return }

        name = service.name
        details = service.details ?? ""
        priceText = String(format: "%.2f", service.price)
        isActive = service.isActive ?? true

        // 🔥 Convert minutes → hours + minutes
        let total = service.durationMinutes
        durationHours = total / 60
        durationMinutesPart = total % 60
    }

    // MARK: - SAVE

    private func saveTapped() {
        localError = ""

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            localError = "Please enter a service name."
            return
        }

        guard let price = Double(priceText) else {
            localError = "Please enter a valid price."
            return
        }

        guard totalDurationMinutes > 0 else {
            localError = "Please select a valid duration."
            return
        }

        isSaving = true

        let data: [String: Any] = [
            "name": name,
            "details": details.isEmpty ? NSNull() : details,
            "price": price,
            "durationMinutes": totalDurationMinutes, // ✅ still minutes
            "isActive": isActive,
            "createdAt": existingService == nil
                ? FieldValue.serverTimestamp()
                : (existingService?.createdAt as Any)
        ]

        let servicesRef = db
            .collection("businesses")
            .document(businessId)
            .collection("services")

        if let service = existingService, let id = service.id {
            servicesRef.document(id).setData(data, merge: true) { error in
                isSaving = false
                if let error {
                    localError = error.localizedDescription
                    return
                }
                dismiss()
            }
        } else {
            servicesRef.addDocument(data: data) { error in
                isSaving = false
                if let error {
                    localError = error.localizedDescription
                    return
                }
                dismiss()
            }
        }
    }

    // MARK: - DELETE

    private func deleteTapped() {
        guard let service = existingService, let id = service.id else { return }

        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(id)
            .delete { _ in
                dismiss()
            }
    }
}
