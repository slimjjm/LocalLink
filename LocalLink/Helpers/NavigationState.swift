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

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }
}
