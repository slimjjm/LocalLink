import Foundation

enum AppRoute: Hashable {

    // Root destinations
    case customerHome
    case businessHome

    // Onboarding
    case businessOnboarding

    // Booking flow
    case bookingSummary(
        businessId: String,
        serviceId: String,
        staffId: String,
        date: Date,
        time: Date
    )

    case bookingSuccess
    case bookingDetail(bookingId: String) 
}
