import Foundation

final class NotificationRouter: ObservableObject {

    static let shared = NotificationRouter()

    @Published var bookingIdToOpen: String? = nil
}
