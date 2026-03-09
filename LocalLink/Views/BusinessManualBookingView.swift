import SwiftUI
import FirebaseFirestore

struct BusinessManualBookingView: View {

    let businessId: String
    let staffId: String

    @State private var selectedDate = Date()
    @State private var isGenerating = false
    @State private var message: String?

    private let generator = AvailabilityGenerator()

    var body: some View {

        Form {

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
                        ProgressView()
                    } else {
                        Text("Generate slots for this day")
                    }
                }
            }

            if let message {

                Section {
                    Text(message)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Manual Booking")
    }

    private func generateSlots() {

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
                    message = "Slots generated. You can now book this day."
                    isGenerating = false
                }

            } catch {

                await MainActor.run {
                    message = "Failed to generate slots."
                    isGenerating = false
                }
            }
        }
    }
}
