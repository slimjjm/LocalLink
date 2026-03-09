import SwiftUI

extension BusinessCategory {

    var icon: String {

        switch self {

        case .barber:
            return "scissors"

        case .nails:
            return "sparkles"

        case .electrician:
            return "bolt.fill"

        case .plumber:
            return "wrench.and.screwdriver"

        case .cleaner:
            return "bubbles.and.sparkles"

        case .gardener:
            return "leaf.fill"

        default:
            return "briefcase.fill"
        }
    }
}
