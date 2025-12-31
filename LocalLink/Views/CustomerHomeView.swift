import SwiftUI

struct CustomerHomeView: View {

    private let DEMO_BUSINESS_ID = "F34E09A6-462A-4F05-B040-EA7D65684436"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Book a service")
                        .font(.largeTitle.bold())

                    Text("Choose a service and pick a time that works for you.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

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

                NavigationLink("Find a business") {
                    BusinessListView()
                }




                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}





