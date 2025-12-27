import SwiftUI
import FirebaseAuth

struct BusinessHomeView: View {
    let businessId: String


    @AppStorage("userType") private var userType = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    menuGrid
                }
                .padding()
            }
            .navigationTitle("Business")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log out", role: .destructive) {
                        try? Auth.auth().signOut()
                        userType = ""
                    }
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Your Dashboard")
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Menu Grid
    private var menuGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 16
        ) {

            NavigationLink {
                BusinessBookingsView()
            } label: {
                menuTile(title: "Bookings", icon: "calendar")
            }

            NavigationLink {
                BusinessStaffListView(businessId: businessId)
            } label: {
                menuTile(title: "Staff", icon: "person.2")
            }


            NavigationLink {
                OpeningHoursView(businessId: businessId)
            } label: {
                menuTile(title: "Opening Hours", icon: "clock")
            }


            NavigationLink {
                Text("Profile (later)")
            } label: {
                menuTile(title: "Profile", icon: "building.2")
            }

            NavigationLink {
                Text("Settings (later)")
            } label: {
                menuTile(title: "Settings", icon: "gearshape")
            }
        }
    }

    // MARK: - Tile
    private func menuTile(title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)

            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}


