import Foundation

enum AppRoute: Hashable {

    // Root
    case startSelection

    // Auth
    case login
    case register

    // Customer
    case customerHome

    // Business
    case businessGate
    case businessOnboarding
    case businessHome

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
