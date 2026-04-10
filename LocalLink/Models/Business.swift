import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Business: Identifiable, Codable, Equatable {

    @DocumentID var id: String?

    let businessName: String
    let address: String?

    let town: String
    let category: String

    let isMobile: Bool
    let serviceTowns: [String]

    let isActive: Bool
    let verified: Bool
    let createdAt: Timestamp

    let stripeAccountId: String?
    let stripeConnected: Bool?
    let stripeChargesEnabled: Bool?
    let ownerId: String?

    // MARK: - Ratings
    let ratingPositiveCount: Int?
    let ratingNegativeCount: Int?

    // MARK: - Profile
    let bio: String?
    let photoURLs: [String]?

    // MARK: - Computed
    var ratingScore: Double {
        let positive = Double(ratingPositiveCount ?? 0)
        let negative = Double(ratingNegativeCount ?? 0)
        let total = positive + negative
        guard total > 0 else { return 0 }
        return positive / total
    }

    var isHighlyRated: Bool {
        ratingScore >= 0.8 && (ratingPositiveCount ?? 0) >= 5
    }
}
