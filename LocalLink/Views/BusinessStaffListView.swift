import SwiftUI
import FirebaseFirestore

struct BusinessStaffListView: View {

    // MARK: - Input
    let businessId: String

    // MARK: - State
    @State private var staff: [Staff] = []
    @State private var isLoading = true
    @State private var showAddStaff = false
    @State private var showPaywall = false

    // MARK: - Constants (V1 limits)
    private let maxFreeStaff = 1

    // MARK: - Services
    private let staffRepo = StaffRepository()

    // MARK: - Computed
    private var canAddStaff: Bool {
        staff.count < maxFreeStaff
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading staff…")
            } else {
                List {
                    staffSection
                    actionSection
                    usageSection
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStaff() }
        .sheet(isPresented: $showAddStaff) {
            AddStaffView(businessId: businessId)
        }
        .alert("Upgrade required", isPresented: $showPaywall) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your plan allows 1 staff member. Multiple staff will be available in a future upgrade.")
        }
    }

    // MARK: - Sections

    private var staffSection: some View {
        Section(header: Text("Staff Members")) {

            if staff.isEmpty {
                Text("No staff added yet")
                    .foregroundColor(.secondary)
            }

            ForEach(staff.indices, id: \.self) { index in
                let member = staff[index]

                VStack(alignment: .leading, spacing: 10) {

                    // Weekly availability editor
                    NavigationLink {
                        WeeklyAvailabilityEditView(
                            businessId: businessId,
                            staff: member
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.headline)

                            if !member.skills.isEmpty {
                                Text(member.skills.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Edit weekly availability")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Active toggle
                    Toggle(
                        "Active",
                        isOn: Binding(
                            get: { staff[index].isActive },
                            set: { newValue in
                                staff[index].isActive = newValue
                                updateStaffActive(
                                    staffId: member.id,
                                    isActive: newValue
                                )
                            }
                        )
                    )

                    if !member.isActive {
                        Text("Inactive")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                if canAddStaff {
                    showAddStaff = true
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Add Staff Member", systemImage: "person.badge.plus")
            }
        }
    }

    private var usageSection: some View {
        Section(
            footer: Text("Staff used: \(staff.count) of \(maxFreeStaff)")
        ) {
            EmptyView()
        }
    }

    // MARK: - Data

    private func loadStaff() {
        isLoading = true
        staffRepo.fetchAllStaff(businessId: businessId) { result in
            DispatchQueue.main.async {
                self.staff = result
                self.isLoading = false
            }
        }
    }

    private func updateStaffActive(staffId: String?, isActive: Bool) {
        guard let staffId else { return }

        staffRepo.updateStaffActive(
            businessId: businessId,
            staffId: staffId,
            isActive: isActive
        ) { _ in
            loadStaff()
        }
    }
}

