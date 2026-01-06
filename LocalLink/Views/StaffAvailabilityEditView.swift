import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct StaffAvailabilityEditView: View {

    // MARK: - Inputs
    let businessId: String
    let staffId: String
    let staffName: String

    // MARK: - State
    @State private var availability = EditableWeeklyAvailability.defaultClosed()
    @State private var isSaving = false

    // MARK: - Services
    private let db = Firestore.firestore()

    // MARK: - Body
    var body: some View {
        Form {
            availabilitySection(title: "Monday", binding: $availability.monday)
            availabilitySection(title: "Tuesday", binding: $availability.tuesday)
            availabilitySection(title: "Wednesday", binding: $availability.wednesday)
            availabilitySection(title: "Thursday", binding: $availability.thursday)
            availabilitySection(title: "Friday", binding: $availability.friday)
            availabilitySection(title: "Saturday", binding: $availability.saturday)
            availabilitySection(title: "Sunday", binding: $availability.sunday)
        }
        .navigationTitle(staffName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    saveAvailability()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadAvailability()
        }
    }

    // MARK: - Day Section

    private func availabilitySection(
        title: String,
        binding: Binding<EditableDayAvailability>
    ) -> some View {
        Section(header: Text(title)) {

            Toggle("Closed", isOn: binding.closed)

            if !binding.closed.wrappedValue {
                TextField("Open", text: binding.open)
                TextField("Close", text: binding.close)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
    }

    // MARK: - Load

    private func loadAvailability() {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snapshot, _ in

                if let data = snapshot?.data(),
                   let availabilityData = data["availability"] {

                    do {
                        let jsonData = try JSONSerialization.data(
                            withJSONObject: availabilityData
                        )

                        availability = try JSONDecoder().decode(
                            EditableWeeklyAvailability.self,
                            from: jsonData
                        )
                    } catch {
                        availability = EditableWeeklyAvailability.defaultClosed()
                    }
                }
            }
    }

    // MARK: - Save

    private func saveAvailability() {
        isSaving = true

        guard let encoded = try? Firestore.Encoder().encode(availability) else {
            isSaving = false
            return
        }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .updateData([
                "availability": encoded
            ]) { _ in
                isSaving = false
            }
    }
}
