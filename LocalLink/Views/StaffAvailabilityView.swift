import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct StaffAvailabilityView: View {

    let businessId: String
    let staff: Staff

    @State private var availability: [String: StaffAvailability] = [:]
    @State private var isLoading = true

    private let db = Firestore.firestore()

    private let days = [
        "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday", "sunday"
    ]

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                availabilityRow(for: day)
            }
        }
        .navigationTitle(staff.name)
        .onAppear {
            loadAvailability()
        }
    }

    private func availabilityRow(for day: String) -> some View {
        let entry = availability[day] ?? StaffAvailability(
            id: day,
            isWorking: false,
            start: "09:00",
            end: "17:00"
        )

        return VStack(alignment: .leading) {
            Toggle(day.capitalized, isOn: Binding(
                get: { entry.isWorking },
                set: { newValue in
                    saveAvailability(
                        day: day,
                        isWorking: newValue,
                        start: entry.start,
                        end: entry.end
                    )
                }
            ))

            if entry.isWorking {
                HStack {
                    TextField("Start", text: Binding(
                        get: { entry.start },
                        set: { saveAvailability(day: day, isWorking: true, start: $0, end: entry.end) }
                    ))

                    Text("to")

                    TextField("End", text: Binding(
                        get: { entry.end },
                        set: { saveAvailability(day: day, isWorking: true, start: entry.start, end: $0) }
                    ))
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Firestore

    private func loadAvailability() {
        isLoading = true

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staff.id!)
            .collection("availability")
            .getDocuments { snapshot, _ in

                snapshot?.documents.forEach {
                    if let model = try? $0.data(as: StaffAvailability.self),
                       let id = model.id {
                        availability[id] = model
                    }
                }

                isLoading = false
            }
    }

    private func saveAvailability(
        day: String,
        isWorking: Bool,
        start: String,
        end: String
    ) {
        let data = StaffAvailability(
            id: day,
            isWorking: isWorking,
            start: start,
            end: end
        )

        do {
            try db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staff.id!)
                .collection("availability")
                .document(day)
                .setData(from: data)

            availability[day] = data

        } catch {
            print("Failed to save availability")
        }
    }
}

