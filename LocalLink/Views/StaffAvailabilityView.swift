import SwiftUI
import FirebaseFirestore

struct StaffAvailabilityView: View {

    let businessId: String
    let staff: Staff

    @Environment(\.dismiss) private var dismiss

    @State private var weeklyAvailability: [String: (isOpen: Bool, open: String, close: String)] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    private let horizonService = AvailabilityHorizonService()

    private let weekdayKeys = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]

    var body: some View {
        Form {

            Section("Staff") {
                Text(staff.name)
                    .font(.headline)
            }

            Section("Weekly availability") {
                ForEach(weekdayKeys, id: \.self) { key in
                    weeklyRow(for: key)
                }
            }

            Section {
                Button {
                    Task { await saveAndGenerate() }
                } label: {
                    HStack {
                        if isSaving { ProgressView() }
                        Text(isSaving ? "Saving…" : "Save & generate next 14 days")
                            .font(.headline)
                    }
                }
                .disabled(isSaving)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadWeeklyAvailability() }
    }

    private func weeklyRow(for weekdayKey: String) -> some View {
        let data = weeklyAvailability[weekdayKey] ?? (false, "09:00", "17:00")

        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { data.isOpen },
                set: { newValue in
                    weeklyAvailability[weekdayKey] = (newValue, data.open, data.close)
                }
            )) {
                Text(weekdayKey.capitalized)
            }

            if data.isOpen {
                HStack {
                    Text("Open")
                    TextField("09:00", text: Binding(
                        get: { data.open },
                        set: { weeklyAvailability[weekdayKey] = (data.isOpen, $0, data.close) }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 80)

                    Text("Close")
                    TextField("17:00", text: Binding(
                        get: { data.close },
                        set: { weeklyAvailability[weekdayKey] = (data.isOpen, data.open, $0) }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 80)
                }
            }
        }
    }

    private func loadWeeklyAvailability() {
        guard let staffId = staff.id else { return }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("weeklyAvailability")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ loadWeeklyAvailability error:", error)
                }

                var result: [String: (Bool, String, String)] = [:]

                snapshot?.documents.forEach { doc in
                    let key = doc.documentID.lowercased() // monday, tuesday...
                    let open = doc["open"] as? String ?? "09:00"
                    let close = doc["close"] as? String ?? "17:00"
                    let closed = doc["closed"] as? Bool ?? true
                    result[key] = (!closed, open, close)
                }

                // fill missing defaults
                for k in weekdayKeys where result[k] == nil {
                    result[k] = (false, "09:00", "17:00")
                }

                DispatchQueue.main.async {
                    weeklyAvailability = result
                }
            }
    }

    @MainActor
    private func saveAndGenerate() async {
        guard let staffId = staff.id else { return }

        isSaving = true
        errorMessage = nil

        // validate times
        for (k, v) in weeklyAvailability where v.isOpen {
            if !TimeHHmm.isValid(v.open) || !TimeHHmm.isValid(v.close) {
                errorMessage = "Invalid time on \(k.capitalized). Use HH:mm (e.g. 09:00)."
                isSaving = false
                return
            }
        }

        let staffRef = db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        do {
            let batch = db.batch()

            weeklyAvailability.forEach { weekdayKey, value in
                let ref = staffRef
                    .collection("weeklyAvailability")
                    .document(weekdayKey) // ✅ monday/tuesday...

                batch.setData([
                    "open": value.open,
                    "close": value.close,
                    "closed": !value.isOpen
                ], forDocument: ref, merge: true)
            }

            try await batch.commit()

            try await horizonService.ensureHorizon(
                businessId: businessId,
                staffId: staffId,
                horizonDays: 14
            )

            isSaving = false
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
