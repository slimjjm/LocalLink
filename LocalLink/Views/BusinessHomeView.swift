import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessHomeView: View {

    @EnvironmentObject private var nav: NavigationState
    @StateObject private var resolver = BusinessResolverViewModel()
    @StateObject private var bookingsVM = BusinessBookingsViewModel()

    var body: some View {

        Group {

            if resolver.isLoading {

                ProgressView("Loading business…")

            } else if !resolver.errorMessage.isEmpty {

                errorState

            } else if let businessId = resolver.selectedBusinessId {

                content(businessId: businessId)

            } else {

                ProgressView("Loading business…")
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Change role") {
                    nav.reset()
                    nav.path.append(.startSelection)
                }
            }
        }
        .onAppear {

            if resolver.businesses.isEmpty {

                print("Current UID:", Auth.auth().currentUser?.uid ?? "nil")
                resolver.load()
            }

            if let businessId = resolver.selectedBusinessId {

                bookingsVM.loadBookings(for: businessId)
                bookingsVM.loadStaff(for: businessId)
            }
        }
    }
    
    private var errorState: some View {

        VStack(spacing: 14) {

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Business not ready")
                .font(.headline)

            Text(resolver.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                resolver.load()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Main Content

    private func content(businessId: String) -> some View {

        ScrollView {

            VStack(spacing: 28) {

                headerSection

                BusinessCapacityTileView(
                    viewModel: bookingsVM
                )

                BusinessEarningsView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)

                BusinessDayScrollerView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )

                staffUsageTile(businessId: businessId)

                menuGrid(businessId: businessId)

                switchRoleButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Welcome")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Business Dashboard")
                .font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Staff Tile

    private func staffUsageTile(businessId: String) -> some View {

        NavigationLink {

            BusinessStaffListView(businessId: businessId)

        } label: {

            HStack(spacing: 16) {

                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {

                    Text("Staff")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Manage staff & availability")
                        .font(.headline)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Menu Grid

    private func menuGrid(businessId: String) -> some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 20
        ) {

            NavigationLink {
                BusinessServiceListView(businessId: businessId)
            } label: {
                menuTile(title: "Services", icon: "scissors")
            }

            NavigationLink {
                BusinessBookingsView(businessId: businessId)
            } label: {
                menuTile(title: "Bookings", icon: "calendar")
            }

            NavigationLink {
                Group {
                    if let firstStaff = bookingsVM.staff.first,
                       let staffId = firstStaff.id {

                        AddBlockTimeView(
                            businessId: businessId,
                            staffId: staffId
                        )
                    } else {
                        Text("Please add a staff member first")
                    }
                }
            } label: {
                menuTile(title: "Block time", icon: "calendar.badge.minus")
            }

            NavigationLink {
                Group {
                    if let firstStaff = bookingsVM.staff.first,
                       let staffId = firstStaff.id {

                        BusinessBookingCalendarView(
                            businessId: businessId,
                            staffId: staffId
                        )
                    } else {
                        Text("Please add a staff member first")
                    }
                }
            } label: {
                menuTile(title: "Calendar", icon: "calendar")
            }

            NavigationLink {
                BusinessProfileView(businessId: businessId)
            } label: {
                menuTile(title: "Profile", icon: "building.2")
            }

            NavigationLink {
                SettingsView()
            } label: {
                menuTile(title: "Settings", icon: "gearshape")
            }
        }
    }

    // MARK: - Switch Role

    private var switchRoleButton: some View {

        Button {

            nav.reset()
            nav.path.append(.startSelection)

        } label: {

            HStack {

                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading) {

                    Text("Back to welcome")
                        .font(.headline)

                    Text("Switch between customer and business mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private func menuTile(title: String, icon: String) -> some View {

        HStack {

            VStack(alignment: .leading, spacing: 8) {

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.headline)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
