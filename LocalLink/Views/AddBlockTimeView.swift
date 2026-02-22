import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct AddBlockTimeView: View {
    
    let businessId: String
    let staffId: String   // ✅ REAL staffId passed in
    
    @Environment(\.dismiss) private var dismiss
    private let service = BlockedTimeService()
    
    @State private var title: String = "Lunch"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isSaving: Bool = false
    
    @State private var repeatType: String = "none"
    @State private var repeatUntil: Date =
        Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    
    @State private var showConflictDialog = false
    @State private var conflictCount = 0
    
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
        .onChange(of: startDate) { newStart in
            if endDate <= newStart {
                endDate = newStart.addingTimeInterval(1800)
            }
        }
        
        .confirmationDialog(
            "This will cancel \(conflictCount) confirmed appointment(s). The customer will be refunded.",
            isPresented: $showConflictDialog,
            titleVisibility: .visible
        ) {
            Button("Continue Anyway", role: .destructive) {
                actuallySaveBlock()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // =========================================
    // SAVE FLOW
    // =========================================
    
    private func save() {
        
        guard isEndAfterStart else { return }
        
        isSaving = true
        
        service.checkConflictingBookings(
            businessId: businessId,
            staffId: staffId,   // ✅ NOW STAFF-SPECIFIC
            startDate: startDate,
            endDate: endDate
        ) { result in
            
            DispatchQueue.main.async {
                
                switch result {
                    
                case .failure(let error):
                    print("❌ Conflict check failed:", error)
                    isSaving = false
                    
                case .success(let count):
                    
                    if count > 0 {
                        conflictCount = count
                        showConflictDialog = true
                        isSaving = false
                    } else {
                        actuallySaveBlock()
                    }
                }
            }
        }
    }
    
    private func actuallySaveBlock() {
        
        isSaving = true
        
        service.addBlock(
            businessId: businessId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            repeatType: repeatType,
            repeatUntil: repeatType == "none" ? nil : repeatUntil
        ) { result in
            
            DispatchQueue.main.async {
                
                switch result {
                    
                case .failure(let error):
                    print("❌ Block save FAILED:", error.localizedDescription)
                    isSaving = false
                    
                case .success:
                    
                    print("✅ Block saved — regenerating slots")
                    
                    Task {
                        
                        do {
                            
                            let generator = SlotGenerator()
                            
                            let blocks = await fetchBlocksForDay()
                            
                            try await generator.generateSlotsForDay(
                                businessId: businessId,
                                staffId: staffId,   // ✅ REAL staff
                                date: startDate,
                                startTime: Calendar.current.startOfDay(for: startDate),
                                endTime: Calendar.current.date(byAdding: .day, value: 1, to: startDate)!,
                                blockedTimes: blocks
                            )
                            
                            print("🎯 Generator complete")
                            
                            DispatchQueue.main.async {
                                isSaving = false
                                dismiss()
                            }
                            
                        } catch {
                            print("❌ Generator failed:", error)
                            isSaving = false
                        }
                    }
                }
            }
        }
    }
    
    private func fetchBlocksForDay() async -> [BlockedTime] {
        
        do {
            
            let snapshot = try await Firestore.firestore()
                .collection("businesses")
                .document(businessId)
                .collection("blockedTimes")
                .getDocuments()
            
            return snapshot.documents.compactMap {
                try? $0.data(as: BlockedTime.self)
            }
            
        } catch {
            print("❌ Failed to fetch blocks:", error)
            return []
        }
    }
}
