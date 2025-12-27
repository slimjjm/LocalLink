import SwiftUI

struct HomeServiceCategoryView: View {

    // TEMP: same demo businessId used in CustomerHomeView
    private let demoBusinessId = "demo-business-id"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Text("Browse Categories")
                    .font(.largeTitle.bold())

                NavigationLink("View Services") {
                    CustomerServiceListView(
                        businessId: demoBusinessId
                    )
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
        }
    }
}
