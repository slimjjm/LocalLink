import SwiftUI

final class NavigationState: ObservableObject {

    @Published var path = NavigationPath()

    func popToRoot() {
        if path.count > 0 {
            path.removeLast(path.count)
        }
        print("🧭 NavigationState.popToRoot() -> path count:", path.count)
    }

    func setRoot(_ route: AppRoute) {
        // Replace the entire stack with a single route
        path = NavigationPath()
        path.append(route)
        print("🧭 NavigationState.setRoot(\(route)) -> path count:", path.count)
    }
}

