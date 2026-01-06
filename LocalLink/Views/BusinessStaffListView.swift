import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessStaffListView: View {

    // MARK: - Input
    let businessId: String

    // MARK: - State
    @State private var staff: [Staff] = []

    @State private var staffSlotsAllowed = 0
    @State private var staffSlotsPurchased = 0

    @State private var showUnlockSheet = false
    @State private var showAddStaff = false
    @State private var isLoading = true

    // A9.2 UI gate + messaging
    @State private var showLimitReached = false
    @State private var staffUsed = 0
    @State private var staffMax = 0

    // MARK: - Services
    private let db = Firestore.firestore()
    private let staffLimitService = StaffLimitService()

    // MARK: - Computed
    private var maxStaffAllowed: Int {
        staffSlotsAllowed + staffSlotsPurchased
    }

    private var canAddStaffLocal: Bool {
        staff.count < maxStaffAllowed
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading staff…")
            } else {
                List {

                    // ✅ NEW: Schedule section (C8 entry point)
                    scheduleSection

                    staffSection
                    actionSection
                    usageSection
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Staff")
        .onAppear { loadData() }
        .sheet(isPresented: $showUnlockSheet) {
            UnlockStaffSlotView {
                unlockStaffSlot()
            }
        }
        .sheet(isPresented: $showAddStaff) {
            AddStaffView(
                businessId: businessId,
                onStaffAdded: { loadData() }
            )
        }
        .alert("Staff limit reached", isPresented: $showLimitReached) {
            Button("Upgrade (coming soon)") { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You’re using \(staffUsed) of \(staffMax) staff slots. Upgrade to add more team members.")
        }
    }

    // MARK: - Sections

    // ✅ NEW SECTION
    private var scheduleSection: some View {
        Section {
            NavigationLink {
                StaffScheduleView(businessId: businessId)
            } label: {
                Label("Schedule", systemImage: "calendar.day.timeline.left")
            }
        } footer: {
            Text("View bookings and free gaps for each staff member.")
        }
    }

    private var staffSection: some View {
        Section(header: Text("Staff Members")) {

            if staff.isEmpty {
                Text("No staff added yet")
                    .foregroundColor(.secondary)
            }

            ForEach(staff) { member in
                VStack(alignment: .leading, spacing: 8) {

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {

                            Text(member.name)
                                .font(.headline)

                            if let skills = member.skills, !skills.isEmpty {
                                Text(skills.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Availability managed via schedule")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle(
                            "Active",
                            isOn: Binding(
                                get: { member.isActive },
                                set: { newValue in
                                    updateStaffActiveStatus(
                                        staffId: member.id,
                                        isActive: newValue
                                    )
                                }
                            )
                        )
                        .labelsHidden()
                    }

                    if !member.isActive {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                // A9.2: always confirm against Firestore (not just local state)
                staffLimitService.fetchLimits(businessId: businessId) { used, max in
                    DispatchQueue.main.async {
                        staffUsed = used
                        staffMax = max

                        if used >= max {
                            showLimitReached = true
                        } else {
                            showAddStaff = true
                        }
                    }
                }
            } label: {
                Label(
                    canAddStaffLocal ? "Add Staff Member" : "Unlock Extra Staff Slot",
                    systemImage: canAddStaffLocal ? "person.badge.plus" : "lock.fill"
                )
            }
        }
    }

    private var usageSection: some View {
        Section(
            footer: Text("Staff used: \(staff.count) of \(maxStaffAllowed)")
        ) {
            EmptyView()
        }
    }

    // MARK: - Firestore

    private func loadData() {
        isLoading = true

        let group = DispatchGroup()

        group.enter()
        loadStaffLimits { group.leave() }

        group.enter()
        loadStaff { group.leave() }

        group.notify(queue: .main) {
            isLoading = false
        }
    }

    private func loadStaffLimits(completion: @escaping () -> Void) {
        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in
                if let data = snapshot?.data() {
                    staffSlotsAllowed = data["staffSlotsAllowed"] as? Int ?? 1
                    staffSlotsPurchased = data["staffSlotsPurchased"] as? Int ?? 0
                }
                completion()
            }
    }

    private func loadStaff(completion: @escaping () -> Void) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { snapshot, _ in
                staff = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []
                completion()
            }
    }

    private func unlockStaffSlot() {
        db.collection("businesses")
            .document(businessId)
            .updateData([
                "staffSlotsPurchased": FieldValue.increment(Int64(1))
            ]) { _ in
                loadData()
            }
    }

    private func updateStaffActiveStatus(staffId: String?, isActive: Bool) {
        guard let staffId else { return }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .updateData([
                "isActive": isActive
            ])
    }
}

