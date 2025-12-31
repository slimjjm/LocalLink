import SwiftUI

struct RootView: View {

    @AppStorage("userType") private var userType: String = ""

    var body: some View {
        switch userType {
        case "customer":
            CustomerHomeView()

        case "business":
            BusinessGateView { businessId in
                BusinessHomeView(businessId: businessId)
            }

        default:
            StartSelectionView()
        }
    }
}
