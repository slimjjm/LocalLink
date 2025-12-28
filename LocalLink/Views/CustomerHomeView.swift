import SwiftUI

struct CustomerHomeView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // HEADER
                VStack(alignment: .leading, spacing: 4) {
                    Text("Book a service")
                        .font(.largeTitle.bold())

                    Text("Choose a service and pick a time that works for you.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // ACTION BUTTON
                NavigationLink {
                    CustomerBookingsView()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text("My bookings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                // SERVICES (🔥 single source of truth)
                CustomerServiceListView(
                    businessId: AppConfig.demoBusinessId
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}




