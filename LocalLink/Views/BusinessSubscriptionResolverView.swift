import SwiftUI

struct BusinessSubscriptionResolverView: View {

    @StateObject private var resolver = BusinessResolverViewModel()

    var body: some View {

        Group {

            if resolver.isLoading {
                ProgressView("Loading…")

            } else if let businessId = resolver.selectedBusinessId {
                BusinessSubscriptionView(businessId: businessId)

            } else {
                Text("No business found")
            }
        }
        .onAppear {
            resolver.load()
        }
    }
}
