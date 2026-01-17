import SwiftUI
import FirebaseFirestore

struct StaffAvailabilityView: View {

    let businessId: String
    let staff: Staff

    @Environment(\.dismiss) private var dismiss

    @State private var weeklyAvailability: [Int: (Bool, String, String)] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    private let horizonService = AvailabilityHorizonService()

    var body: some View {
        Form {

            Section("Staff") {
                Text(staff.name)
                    .font(.headline)
            }

            Section("Weekly availability") {
                ForEach(1...7, id: \.self) { weekday in
                    weeklyRow(for: weekday)
                }
            }

            Section {
                Button {
                    saveAndGenerate()
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

    // MARK: - Weekly Row
    private func weeklyRow(for weekday: Int) -> some View {
        let data = weeklyAvailability[weekday] ?? (false, "09:00", "17:00")

        return VStack(alignment: .leading) {
            Toggle(isOn: Binding(
                get: { data.0 },
                set: { newValue in
                    weeklyAvailability[weekday] = (newValue, data.1, data.2)
                }
            )) {
                Text(weekdayName(weekday))
            }

            if data.0 {
                HStack {
                    Text("Open")
                    TextField("Start", text: Binding(
                        get: { data.1 },
                        set: { weeklyAvailability[weekday] = (data.0, $0, data.2) }
                    ))
                    .frame(width: 80)

                    Text("Close")
                    TextField("End", text: Binding(
                        get: { data.2 },
                        set: { weeklyAvailability[weekday] = (data.0, data.1, $0) }
                    ))
                    .frame(width: 80)
                }
            }
        }
    }

    // MARK: - Load weekly template
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

                var result: [Int: (Bool, String, String)] = [:]

                snapshot?.documents.forEach { doc in
                    let weekday = Int(doc.documentID) ?? 0
                    let open = doc["open"] as? String ?? "09:00"
                    let close = doc["close"] as? String ?? "17:00"
                    let closed = doc["closed"] as? Bool ?? true
                    result[weekday] = (!closed, open, close)
                }

                for day in 1...7 where result[day] == nil {
                    result[day] = (false, "09:00", "17:00")
                }

                DispatchQueue.main.async {
                    weeklyAvailability = result
                }
            }
    }

    // MARK: - Save + Generate
    private func saveAndGenerate() {
        guard let staffId = staff.id else { return }

        isSaving = true
        errorMessage = nil

        let batch = db.batch()

        weeklyAvailability.forEach { weekday, value in
            let ref = db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("weeklyAvailability")
                .document(String(weekday))

            batch.setData(
                [
                    "open": value.1,
                    "close": value.2,
                    "closed": !value.0
                ],
                forDocument: ref
            )
        }

        batch.commit { error in
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSaving = false
                }
                return
            }

            Task {
                _ = await horizonService.ensureHorizon(
                    businessId: businessId,
                    staffId: staffId,
                    horizonDays: 14
                )

                await MainActor.run {
                    self.isSaving = false
                    dismiss()
                }
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}

