import SwiftUI

struct BusinessStaffListView: View {

    let businessId: String

    @State private var staff: [Staff] = []
    @State private var isLoading = true
    @State private var showAddStaff = false
    @State private var showPaywall = false

    private let maxFreeStaff = 1
    private let staffRepo = StaffRepository()

    private var canAddStaff: Bool {
        staff.count < maxFreeStaff
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading staff…")
            } else {
                List {
                    Section("Staff Members") {

                        if staff.isEmpty {
                            Text("No staff added yet")
                                .foregroundColor(.secondary)
                        }

                        ForEach(staff) { member in
                            staffRow(member)
                        }
                    }

                    Section {
                        Button {
                            canAddStaff ? (showAddStaff = true) : (showPaywall = true)
                        } label: {
                            Label("Add Staff Member", systemImage: "person.badge.plus")
                        }
                    }

                    Section(
                        footer: Text("Staff used: \(staff.count) of \(maxFreeStaff)")
                    ) { EmptyView() }
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
            Text("Your plan allows 1 staff member.")
        }
    }

    // MARK: - Row

    private func staffRow(_ member: Staff) -> some View {

        Section {

            HStack {
                Text(member.name)
                    .font(.headline)
                Spacer()
            }

            NavigationLink {
                EditStaffSkillsView(
                    businessId: businessId,
                    staffId: member.id ?? ""
                )
            } label: {
                rowLabel("Edit Skills")
            }

            NavigationLink {
                WeeklyAvailabilityEditView(
                    businessId: businessId,
                    staffId: member.id ?? ""
                )
            } label: {
                rowLabel("Edit Weekly Availability")
            }

            Toggle(
                "Active",
                isOn: Binding(
                    get: { member.isActive },
                    set: { newValue in
                        updateStaffActive(
                            staffId: member.id,
                            isActive: newValue
                        )
                    }
                )
            )
        }
    }

    // MARK: - UI

    private func rowLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
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
