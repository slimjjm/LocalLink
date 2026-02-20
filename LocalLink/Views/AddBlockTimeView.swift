import SwiftUI

struct AddBlockTimeView: View {

    let businessId: String

    @Environment(\.dismiss) private var dismiss
    private let service = BlockedTimeService()

    // MARK: - State

    @State private var title: String = "Lunch"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isSaving: Bool = false

    // Recurrence
    @State private var repeatType: String = "none"
    @State private var repeatUntil: Date =
        Calendar.current.date(byAdding: .month, value: 3, to: Date())!

    // MARK: - Validation

    private var isEndAfterStart: Bool {
        endDate > startDate
    }

    // MARK: - Options

    private let options = [
        "Lunch",
        "Training",
        "Holiday",
        "Walk-ins",
        "Personal"
    ]

    var body: some View {
        Form {

            // MARK: - Reason
            Section("Reason") {
                Picker("Type", selection: $title) {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                    }
                }
            }

            // MARK: - Start
            Section("Start") {
                DatePicker(
                    "Start time",
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            // MARK: - End
            Section("End") {
                DatePicker(
                    "End time",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            // MARK: - Repeat
            Section("Repeat") {
                Picker("Repeat", selection: $repeatType) {
                    Text("Does not repeat").tag("none")
                    Text("Every day").tag("daily")
                    Text("Every week").tag("weekly")
                    Text("Every month").tag("monthly")
                }

                if repeatType != "none" {
                    DatePicker(
                        "Repeat until",
                        selection: $repeatUntil,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }
            }

            // MARK: - Save
            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save block")
                    }
                }
                .disabled(isSaving || !isEndAfterStart)
            }
        }
        .navigationTitle("Block time")
        .onAppear {
            print("BLOCK TIME VIEW OPENED:", businessId)
        }
        .onChange(of: startDate) { newStart in
            if endDate <= newStart {
                endDate = newStart.addingTimeInterval(1800)
            }
        }
    }

    // MARK: - Save

    private func save() {
        guard isEndAfterStart else { return }

        isSaving = true

        service.addBlock(
            businessId: businessId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            repeatType: repeatType,
            repeatUntil: repeatType == "none" ? nil : repeatUntil
        ) { _ in
            DispatchQueue.main.async {
                isSaving = false
                dismiss()
            }
        }
    }
}
