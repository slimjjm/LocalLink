import SwiftUI

struct OpeningHoursView: View {

    let businessId: String
    @StateObject private var viewModel: AvailabilityViewModel

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(businessId: String) {
        self.businessId = businessId
        _viewModel = StateObject(wrappedValue: AvailabilityViewModel(businessId: businessId))
    }

    var body: some View {
        List {
            // Top controls (slot interval + capacity) — optional but useful
            Section("Booking settings") {
                Picker("Slot interval", selection: $viewModel.slotInterval) {
                    ForEach(viewModel.allowedIntervals, id: \.self) { mins in
                        Text("\(mins) min").tag(mins)
                    }
                }

                Stepper("Capacity: \(viewModel.capacity)", value: $viewModel.capacity, in: 1...20)
            }

            // Weekly opening hours
            Section("Opening hours") {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading…")
                        Spacer()
                    }
                } else {
                    ForEach($viewModel.days) { $day in
                        DayEditorRow(day: $day)
                    }
                }
            }

            if !viewModel.errorMessage.isEmpty {
                Section {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Opening Hours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveWholeWeek()
                }
                .disabled(viewModel.isLoading)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: viewModel.didSave) { didSave in
            guard didSave else { return }
            alertTitle = "Saved"
            alertMessage = "Your opening hours have been updated."
            showAlert = true
        }
    }

    // MARK: - Save

    private func saveWholeWeek() {
        // Validate every day before saving
        do {
            for day in viewModel.days {
                // Your validator expects optionals for open/close.
                // When closed, we pass nils so it won’t throw "closedDayHasTimes".
                try AvailabilityValidator.validate(day: day)

            }

            viewModel.saveAvailability()

        } catch {
            alertTitle = "Fix opening hours"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Row Editor

private struct DayEditorRow: View {

    @Binding var day: EditableDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(displayName(for: day.day))
                    .font(.headline)

                Spacer()

                Toggle("Closed", isOn: $day.closed)
                    .labelsHidden()
            }

            if day.closed {
                Text("Closed")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                TimePickerRow(title: "Open", time: $day.start)
                TimePickerRow(title: "Close", time: $day.end)
            }
        }
        .padding(.vertical, 6)
    }

    private func displayName(for key: String) -> String {
        switch key.lowercased() {
        case "monday": return "Monday"
        case "tuesday": return "Tuesday"
        case "wednesday": return "Wednesday"
        case "thursday": return "Thursday"
        case "friday": return "Friday"
        case "saturday": return "Saturday"
        case "sunday": return "Sunday"
        default: return key.capitalized
        }
    }
}

