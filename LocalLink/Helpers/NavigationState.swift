import SwiftUI

@MainActor
final class NavigationState: ObservableObject {

    @Published var path: [AppRoute] = []

    func reset() {
        path.removeAll()
    }

    func setRoot(_ route: AppRoute) {
        path = [route]
    }
}
