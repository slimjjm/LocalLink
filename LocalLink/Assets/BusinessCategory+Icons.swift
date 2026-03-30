import SwiftUI

extension BusinessCategory {

    var icon: Image {
        switch self {
        case .cleaner:
            return Image(systemName: "bubbles.and.sparkles")
        case .dogWalker:
            return Image(systemName: "figure.walk")
        case .personalTrainer:
            return Image(systemName: "figure.strengthtraining.traditional")
        case .dogGroomer:
            return Image(systemName: "pawprint.fill")
        case .hairSalon:
            return Image(systemName: "person.crop.circle")
        case .barber:
            return Image(systemName: "scissors")
        case .nails:
            return Image(systemName: "sparkles")
        case .gardener:
            return Image(systemName: "leaf.fill")
        }
    }
}
