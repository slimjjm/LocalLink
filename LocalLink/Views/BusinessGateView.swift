import SwiftUI
import FirebaseAuth

struct BusinessGateView<Content: View>: View {

    // 🔑 D5 DEMO BUSINESS ID
    // Replace with the exact businessId from Firestore
    private let demoBusinessId = "F34E09A6-462A-4F05-B040-EA7D65684436"

    let content: (String) -> Content

    var body: some View {
        // 🚀 For D5 we bypass onboarding entirely
        content(demoBusinessId)
    }
}
