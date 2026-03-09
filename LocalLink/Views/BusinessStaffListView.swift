import SwiftUI
import FirebaseFirestore

struct BusinessStaffListView: View {

    let businessId: String

    @StateObject private var gateVM = StaffUnlockGateViewModel()

    @State private var staff: [Staff] = []
    @State private var isLoadingStaff = true

    @State private var showAddStaff = false
    @State private var showPaywall = false
    @State private var showSubscription = false

    @State private var isSavingOrder = false

    private let staffRepo = StaffRepository()

    // MARK: - Derived

    private var allowedSeats: Int { max(1, gateVM.allowedStaff) }

    private var sortedStaff: [Staff] {
        staff.sorted { ($0.seatRank ?? 9999) < ($1.seatRank ?? 9999) }
    }

    private var entitledStaffIds: Set<String> {
        Set(sortedStaff.prefix(allowedSeats).compactMap { $0.id })
    }

    var body: some View {
        Group {
            if isLoadingStaff || gateVM.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading staff…")
                    Spacer()
                }
            } else {
                List {

                    // MARK: Capacity Tile
                    Section {
                        StaffUnlockTile(
                            businessId: businessId,
                            staffCount: gateVM.staffCount,
                            allowed: gateVM.allowedStaff,
                            canAdd: gateVM.canAddStaff,
                            onUnlockTapped: { showPaywall = true },
                            onManageTapped: { showSubscription = true }
                        )
                    }

                    // MARK: Staff Members
                    Section("Staff Members") {

                        if staff.isEmpty {
                            ContentUnavailableView(
                                "No staff yet",
                                systemImage: "person.2",
                                description: Text("Add staff members to manage bookings.")
                            )
                        }

                        ForEach(sortedStaff) { member in
                            staffRow(member)
                        }
                        .onMove(perform: isSavingOrder ? nil : moveStaff)
                    }

                    // MARK: Add Staff
                    Section {
                        Button {
                            if gateVM.canAddStaff {
                                showAddStaff = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Label("Add Staff Member", systemImage: "person.badge.plus")
                                .foregroundColor(AppColors.primary)
                        }
                        .disabled(isSavingOrder)
                    }

                    Section(
                        footer: Text("Active seats used: \(gateVM.staffCount) of \(gateVM.allowedStaff)")
                    ) { EmptyView() }

                    if isSavingOrder {
                        Section {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Saving priority order…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }

                    if let err = gateVM.errorMessage {
                        Section {
                            Text(err)
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .toolbar {
                    EditButton()
                        .disabled(isSavingOrder)
                }
            }
        }
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            gateVM.start(businessId: businessId)
            loadStaff()
        }
        .onDisappear {
            gateVM.stop()
        }

        // MARK: - Sheets

        .sheet(isPresented: $showAddStaff) {
            AddStaffView(
                businessId: businessId,
                onUnlockTapped: { showPaywall = true }
            )
            .onDisappear { loadStaff() }
        }

        .sheet(isPresented: $showPaywall) {
            StaffUnlockView(
                businessId: businessId,
                onSuccess: { loadStaff() }
            )
        }

        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                BusinessSubscriptionView(businessId: businessId)
            }
        }
    }

    // MARK: - Staff Row

    private func staffRow(_ member: Staff) -> some View {

        let id = member.id ?? ""
        let lockedByEntitlement = !entitledStaffIds.contains(id)

        return Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {

                    HStack(spacing: 8) {
                        Text(member.name)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(AppColors.charcoal)

                        if lockedByEntitlement {
                            Text("LOCKED")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.primary.opacity(0.15))
                                .foregroundColor(AppColors.primary)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Priority \(member.seatRank ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
            .disabled(lockedByEntitlement)
            .opacity(lockedByEntitlement ? 0.55 : 1)

            NavigationLink {
                WeeklyAvailabilityEditView(
                    businessId: businessId,
                    staffId: member.id ?? ""
                )
            } label: {
                rowLabel("Edit Weekly Availability")
            }
            .disabled(lockedByEntitlement)
            .opacity(lockedByEntitlement ? 0.55 : 1)

            if lockedByEntitlement {
                Text("This staff member is locked because your plan allows \(allowedSeats) active seat(s).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Reorder

    private func moveStaff(from source: IndexSet, to destination: Int) {
        var reordered = sortedStaff
        reordered.move(fromOffsets: source, toOffset: destination)

        // Re-assign ranks locally so UI reflects instantly
        let withRanks = reordered.enumerated().map { idx, s -> Staff in
            var copy = s
            copy.seatRank = idx
            return copy
        }

        staff = withRanks
        persistSeatRanks()
    }

    private func persistSeatRanks() {
        isSavingOrder = true

        Task {
            do {
                try await staffRepo.updateSeatRanks(
                    businessId: businessId,
                    orderedStaff: staff
                )

                // Optional: if you want server enforcement to re-check after reorder
                // await staffRepo.reconcileSeatEnforcementNow(businessId: businessId)

            } catch {
                print("❌ updateSeatRanks failed:", error.localizedDescription)
            }

            isSavingOrder = false
            loadStaff()
        }
    }

    // MARK: - Helpers

    private func rowLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func loadStaff() {
        isLoadingStaff = true

        staffRepo.fetchAllStaff(businessId: businessId) { result in
            DispatchQueue.main.async {
                self.staff = result
                self.isLoadingStaff = false
            }
        }
    }
}
