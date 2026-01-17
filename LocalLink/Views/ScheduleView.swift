import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ScheduleView: View {

    // MARK: - Inputs
    let businessId: String

    // MARK: - State
    @State private var staffList: [Staff] = []
    @State private var selectedStaff: Staff?
    @State private var selectedDate: Date = Date()
    @State private var slots: [Date] = []
    @State private var isLoading = false

    // Remember last selected staff (device-local)
    @AppStorage("lastSelectedStaffId") private var lastSelectedStaffId: String?

    // MARK: - Services
    private let db = Firestore.firestore()
    private let availabilityRepo = StaffDateAvailabilityRepository()

    // MARK: - View
    var body: some View {
        VStack(spacing: 12) {

            // Staff selector
            if !staffList.isEmpty {
                Picker(
                    "Staff",
                    selection: Binding(
                        get: { selectedStaff?.id ?? "" },
                        set: { newId in
                            guard let match = staffList.first(where: { $0.id == newId }) else { return }
                            selectedStaff = match
                            lastSelectedStaffId = match.id
                            loadSlots()
                        }
                    )
                ) {
                    ForEach(staffList) { member in
                        Text(member.name)
                            .tag(member.id ?? "")
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            // Date picker
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .onChange(of: selectedDate) { _ in
                loadSlots()
            }

            // Slots
            content
        }
        .navigationTitle("Schedule")
        .onAppear {
            loadStaff()
        }
    }

    // MARK: - Content State
    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading schedule…")
                .padding()
        } else if slots.isEmpty {
            ContentUnavailableView(
                "No availability",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("No slots for this staff on this day.")
            )
        } else {
            List(slots, id: \.self) { slot in
                Text(slot.formatted(date: .omitted, time: .shortened))
            }
        }
    }

    // MARK: - Load staff
    private func loadStaff() {
        isLoading = true

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .order(by: "name")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ loadStaff error:", error)
                }

                let list = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []

                DispatchQueue.main.async {
                    self.staffList = list
                    self.restoreSelection()
                }
            }
    }

    // MARK: - Restore selection
    private func restoreSelection() {
        if
            let lastId = lastSelectedStaffId,
            let match = staffList.first(where: { $0.id == lastId })
        {
            selectedStaff = match
        } else {
            selectedStaff = staffList.first
            lastSelectedStaffId = staffList.first?.id
        }

        loadSlots()
    }

    // MARK: - Load slots (date-based)
    private func loadSlots() {
        guard let staff = selectedStaff, let staffId = staff.id else {
            slots = []
            isLoading = false
            return
        }

        isLoading = true
        slots = []

        availabilityRepo.fetchAvailability(
            businessId: businessId,
            staffId: staffId,
            date: selectedDate
        ) { availability in

            DispatchQueue.main.async {
                guard let availability else {
                    self.slots = []
                    self.isLoading = false
                    return
                }

                self.slots = SlotBuilder.buildSlots(
                    date: self.selectedDate,
                    startTime: availability.startTime,
                    endTime: availability.endTime,
                    intervalMinutes: 30 // V1 fixed
                )

                self.isLoading = false
            }
        }
    }
}

