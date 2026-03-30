import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct AddBlockTimeView: View {

    let businessId: String
    let staffId: String

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = "Lunch"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isSaving: Bool = false

    // 🔥 Conflict Flow State
    @State private var conflicts: [BookingConflict] = []
    @State private var showConflictSheet = false
    @State private var showConfirmCancel = false

    private let db = Firestore.firestore()
    private let conflictService = BlockConflictService()

    private var isEndAfterStart: Bool {
        endDate > startDate
    }

    private let options = [
        "Lunch",
        "Training",
        "Holiday",
        "Walk-ins",
        "Personal"
    ]

    var body: some View {

        Form {

            Section("Reason") {
                Picker("Type", selection: $title) {
                    ForEach(options, id: \.self) {
                        Text($0)
                    }
                }
            }

            Section("Start") {
                DatePicker(
                    "Start time",
                    selection: $startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("End") {
                DatePicker(
                    "End time",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            .onChange(of: startDate) { newValue in
                endDate = newValue.addingTimeInterval(1800)
            }
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

        // =================================================
        // CONFLICT SHEET
        // =================================================
        .sheet(isPresented: $showConflictSheet) {
            BlockConflictSheet(
                conflicts: conflicts,
                onCancelBlock: {
                    showConflictSheet = false
                },
                onEditBlock: {
                    showConflictSheet = false
                },
                onContinue: {
                    showConflictSheet = false
                    showConfirmCancel = true
                }
            )
        }

        // =================================================
        // CONFIRM CANCELLATION SHEET
        // =================================================
        .sheet(isPresented: $showConfirmCancel) {
            ConfirmBookingCancellationView(
                conflicts: conflicts,
                onConfirm: {
                    Task {
                        do {
                            try await conflictService.cancelBookings(
                                conflicts: conflicts,
                                staffId: staffId,
                                blockId: UUID().uuidString
                            )

                            try await applyBlockAndRegen()

                            showConfirmCancel = false
                        } catch {
                            print("❌ Cancellation failed:", error)
                        }
                    }
                },
                onBack: {
                    showConfirmCancel = false
                }
            )
        }
    }

    // =================================================
    // SAVE ENTRY POINT
    // =================================================

    private func save() {

        guard isEndAfterStart else { return }
        isSaving = true

        Task {
            do {

                // 1️⃣ Check conflicts FIRST
                let foundConflicts = try await conflictService.fetchConflictingBookings(
                    businessId: businessId,
                    staffId: staffId,
                    startDate: startDate,
                    endDate: endDate
                )

                if !foundConflicts.isEmpty {

                    await MainActor.run {
                        conflicts = foundConflicts
                        isSaving = false
                        showConflictSheet = true
                    }

                    return
                }

                // 2️⃣ No conflicts → proceed normally
                try await applyBlockAndRegen()

            } catch {
                print("❌ Save block failed:", error)
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    // =================================================
    // APPLY BLOCK + SLOT LOGIC
    // =================================================

    private func applyBlockAndRegen() async throws {

        if isFullDayBlock {
            try await addDayBlock()
        } else {
            try await addTimeBlock()
        }

        try await AvailabilityGenerator().regenerateDays(
            businessId: businessId,
            staffId: staffId,
            startDate: startDate,
            numberOfDays: 30
        )

        await MainActor.run {
            isSaving = false
            dismiss()
        }
    }

    // =================================================
    // FULL DAY CHECK
    // =================================================

    private var isFullDayBlock: Bool {

        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        return start == end
        && Calendar.current.component(.hour, from: startDate) == 0
        && Calendar.current.component(.minute, from: startDate) == 0
    }

    // =================================================
    // ADD DAY BLOCK
    // =================================================

    private func addDayBlock() async throws {

        let block = DayBlock(
            staffId: staffId,
            startDate: Calendar.current.startOfDay(for: startDate),
            endDate: Calendar.current.startOfDay(for: endDate),
            reason: title
        )

        _ = try db
            .collection("businesses")
            .document(businessId)
            .collection("dayBlocks")
            .addDocument(from: block)

        print("📅 DayBlock added")
    }

    // =================================================
    // ADD TIME BLOCK
    // =================================================

    private func addTimeBlock() async throws {

        let block = TimeBlock(
            staffId: staffId,
            startDate: startDate,
            endDate: endDate,
            title: title
        )

        _ = try db
            .collection("businesses")
            .document(businessId)
            .collection("timeBlocks")
            .addDocument(from: block)

        print("⏱ TimeBlock added")
    }
}
