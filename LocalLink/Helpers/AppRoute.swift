import Foundation

enum AppRoute: Hashable {
    
    // Auth
    case login
    case register
    
    // Customer
    case customerHome
    
    // Business
    case businessGate
    case businessOnboarding
    case businessHome
    
    // Staff
    case editStaffSkills(businessId: String, staffId: String, navId: UUID)
    case editWeeklyAvailability(businessId: String, staffId: String, navId: UUID)
    
    // Booking flow
    case bookingSummary(
        businessId: String,
        serviceId: String,
        staffId: String,
        slotId: String,
        date: Date,
        time: Date,
        customerAddress: String?
    )
    
    case bookingSuccess(
        businessId: String,
        bookingId: String
    )
    
    case bookingDetail(bookingId: String, role: String)
}
