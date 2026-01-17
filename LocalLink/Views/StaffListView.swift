import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct StaffListView: View {

    // MARK: - Inputs
    let businessId: String
    let staffSlotsAllowed: Int
    let staffSlotsPurchased: Int

    // MARK: - State
    @State private var staff: [Staff] = []
    @State private var isLoading = true
    @State private var showAddStaff = false

    // MARK: - Firestore
    private let db = Firestore.firestore()

    // MARK: - Computed
    private var maxStaffAllowed: Int {
        staffSlotsAllowed + staffSlotsPurchased
    }

    private var canAddStaff: Bool {
        staff.count < maxStaffAllowed
    }

    // MARK: - View
    var body: some View {
        VStack(spacing: 16) {

            header

            if isLoading {
                ProgressView("Loading staff…")
            } else if staff.isEmpty {
                emptyState
            } else {
                staffList
            }

            addStaffButton
        }
        .padding()
        .navigationTitle("Staff")
        .onAppear(perform: loadStaff)
        .sheet(isPresented: $showAddStaff) {
            AddStaffView(businessId: businessId)
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Staff Members")
                .font(.title.bold())

            Text("\(staff.count) of \(maxStaffAllowed) slots used")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Staff List
    private var staffList: some View {
        List {
            ForEach(staff) { member in
                VStack(alignment: .leading, spacing: 8) {

                    // Top row
                    HStack(spacing: 12) {
                        Circle()
                            .fill(member.isActive ? .green : .gray)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.headline)

                            if !member.skills.isEmpty {
                                Text(member.skills.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }

                    // ✅ THIS IS THE BUTTON YOU EXPECT
                    NavigationLink {
                        StaffAvailabilityView(
                            businessId: businessId,
                            staff: member
                        )
                    } label: {
                        Text("Availability & Generate slots")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 6)
            }
            .onDelete(perform: deleteStaff)
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No staff added yet")
                .font(.headline)

            Text("Add your first staff member to start taking bookings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Staff Button
    private var addStaffButton: some View {
        Button {
            showAddStaff = true
        } label: {
            Text(canAddStaff ? "Add Staff Member" : "Staff limit reached")
                .frame(maxWidth: .infinity)
                .padding()
                .background(canAddStaff ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(!canAddStaff)
    }

    // MARK: - Firestore
    private func loadStaff() {
        isLoading = true

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                isLoading = false

                if let error = error {
                    print("❌ Failed to load staff:", error)
                    return
                }

                staff = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []
            }
    }

    private func deleteStaff(at offsets: IndexSet) {
        for index in offsets {
            let member = staff[index]
            guard let staffId = member.id else { continue }

            db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .delete()

            staff.remove(at: index)
        }
    }
}
