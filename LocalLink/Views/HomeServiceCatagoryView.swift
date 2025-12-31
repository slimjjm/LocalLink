import SwiftUI

struct HomeServiceCategoryView: View {

    let businessId: String   // 👈 REQUIRED INPUT

    var body: some View {
        VStack(spacing: 24) {

            Text("Browse Categories")
                .font(.largeTitle.bold())

            NavigationLink("View Services") {
                CustomerServiceListView(
                    businessId: businessId
                )
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Categories")
    }
}

