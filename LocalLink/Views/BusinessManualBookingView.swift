import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessManualBookingView: View {

    let businessId: String
    let staff: Staff

    @State private var selectedDate = Date().localMidnight()

    @State private var isGenerating = false
    @State private var isLoadingSlots = false

    @State private var message: String?

    @State private var availableSlots: [AvailableSlot] = []
    @State private var selectedSlot: AvailableSlot?

    private let generator = AvailabilityGenerator()
    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    var body: some View {

        List {

            Section("Select Date") {

                DatePicker(
                    "Booking date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
            }

            Section {

                Button {

                    generateSlots()

                } label: {

                    if isGenerating {

                        HStack {
                            ProgressView()
                            Text("Generating…")
                        }

                    } else {

                        Text("Generate slots for this day")
                    }
                }
                .disabled(isGenerating || staff.id == nil)
            }

            if let message {

                Section {

                    Text(message)
                        .foregroundColor(.secondary)
                }
            }

            Section("Available Slots") {

                if isLoadingSlots {

                    HStack {

                        ProgressView()

                        Text("Loading slots…")
                            .foregroundColor(.secondary)
                    }

                } else if availableSlots.isEmpty {

                    Text("No available slots for this day.")
                        .foregroundColor(.secondary)

                } else {

                    ForEach(availableSlots) { slot in

                        Button {

                            selectedSlot = slot

                        } label: {

                            HStack {

                                VStack(alignment: .leading, spacing: 4) {

                                    Text(
                                        slot.startTime.formatted(
                                            date: .omitted,
                                            time: .shortened
                                        )
                                    )

                                    Text(
                                        "\(slot.startTime.formatted(date: .omitted, time: .shortened)) → \(slot.endTime.formatted(date: .omitted, time: .shortened))"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Manual Booking")
        .navigationBarTitleDisplayMode(.inline)

        .onAppear {

            loadSlotsForSelectedDay()
        }

        .onChange(of: selectedDate) { _ in

            message = nil
            loadSlotsForSelectedDay()
        }

        .sheet(item: $selectedSlot, onDismiss: {

            loadSlotsForSelectedDay()

        }) { slot in

            BusinessQuickBookingView(
                businessId: businessId,
                staffId: staff.id ?? "",
                startTime: slot.startTime
            )
        }
    }

    // MARK: - Generate slots

    private func generateSlots() {

        guard let staffId = staff.id else {

            message = "Missing staff id."
            return
        }

        isGenerating = true
        message = nil

        Task {

            do {

                try await generator.regenerateDays(
                    businessId: businessId,
                    staffId: staffId,
                    startDate: selectedDate,
                    numberOfDays: 1
                )

                await MainActor.run {

                    isGenerating = false
                    message = "Slots generated. Select a slot below."

                    loadSlotsForSelectedDay()
                }

            } catch {

                await MainActor.run {

                    isGenerating = false
                    message = "Failed to generate slots."
                }
            }
        }
    }

    // MARK: - Load slots

    private func loadSlotsForSelectedDay() {

        guard let staffId = staff.id else {

            availableSlots = []
            return
        }

        isLoadingSlots = true
        availableSlots = []

        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availableSlots")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("startTime", isLessThan: Timestamp(date: end))
            .whereField("isBooked", isEqualTo: false)
            .order(by: "startTime")
            .getDocuments { snap, error in

                DispatchQueue.main.async {

                    isLoadingSlots = false

                    if let error = error {
                        availableSlots = []
                        message = error.localizedDescription
                        print("loadSlotsForSelectedDay error:", error.localizedDescription)
                        return
                    }

                    let slots = snap?.documents.compactMap {

                        try? $0.data(as: AvailableSlot.self)

                    } ?? []

                    availableSlots = slots
                }
            }
    }
}
