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
        }
    }

    // MARK: - Error State

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
                monthlyRevenueCard(businessId: businessId)
                todaysJobsSection(businessId: businessId)
                selectedBusinessHint
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

    // MARK: - Monthly Revenue Card

    private func monthlyRevenueCard(businessId: String) -> some View {
        VStack(spacing: 16) {

            HStack {
                Button(action: {
                    bookingsVM.goToPreviousMonth()
                }) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(bookingsVM.selectedMonthLabel)
                    .font(.headline)

                Spacer()

                Button(action: {
                    bookingsVM.goToNextMonth()
                }) {
                    Image(systemName: "chevron.right")
                }
            }

            Divider()

            HStack {

                VStack(alignment: .leading) {
                    Text("Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("£\(Double(bookingsVM.monthlyRevenueEarned)/100, specifier: "%.2f")")
                        .font(.title3.bold())
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Projected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("£\(Double(bookingsVM.monthlyProjectedIncome)/100, specifier: "%.2f")")
                        .font(.title3.bold())
                }
            }

            HStack {

                VStack(alignment: .leading) {
                    Text("Refunded")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("£\(Double(bookingsVM.monthlyRefunds)/100, specifier: "%.2f")")
                        .font(.title3.bold())
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(bookingsVM.monthlyCompletedCount)")
                        .font(.title3.bold())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .onAppear {
            bookingsVM.loadBookings(for: businessId)
        }
    }

    // MARK: - Today's Jobs

    private func todaysJobsSection(businessId: String) -> some View {
        TodayBookingsView(businessId: businessId)
    }

    // MARK: - Selected Business Hint

    private var selectedBusinessHint: some View {
        Group {
            if resolver.businesses.count > 1,
               let first = resolver.businesses.first {

                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current business")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(first.name)
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()

                    Text("Multi-business")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.14))
                        )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
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
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.12))
                    )

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
                AddBlockTimeView(businessId: businessId)
            } label: {
                menuTile(title: "Block time", icon: "calendar.badge.minus")
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

    // MARK: - Back to Welcome

    private var switchRoleButton: some View {
        Button {
            nav.reset()
            nav.path.append(.startSelection)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.orange.opacity(0.4))
                    )
            )
        }
    }

    // MARK: - Tile UI

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
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 6,
                    x: 0,
                    y: 4
                )
        )
    }
}

