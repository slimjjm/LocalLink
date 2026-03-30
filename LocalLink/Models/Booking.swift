import Foundation
import FirebaseFirestoreSwift

struct Booking: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    let businessId: String
    let customerId: String
    let serviceId: String
    
    // 🔥 ADD THIS
    let businessName: String?
    
    // OPTIONAL display fields
    let serviceName: String?
    let serviceDurationMinutes: Int?
    
    let price: Int
    
    let staffId: String
    let staffName: String?
    
    let customerName: String?
    let customerAddress: String?
    
    let paymentIntentId: String?
    
    let bookingDay: Date?
    let startDate: Date
    let endDate: Date
    
    let status: BookingStatus
    
    let createdAt: Date?
    
    let rating: String?
    let ratedAt: Date?
    
    // chat counters
    let unreadForCustomer: Int?
    let unreadForBusiness: Int?
    
    // optional
    let slotId: String?
    
    // MARK: - Computed helpers
    
    var unreadCustomerCount: Int {
        unreadForCustomer ?? 0
    }
    
    var unreadBusinessCount: Int {
        unreadForBusiness ?? 0
    }
    
    // MARK: - UI helpers
    
    var safeServiceName: String {
        serviceName ?? "Service"
    }
    
    var safeStaffName: String {
        staffName ?? "Staff"
    }
    
    var safeCustomerName: String {
        customerName ?? "Customer"
    }
    
    var safeBusinessName: String {
        businessName ?? "Business"
    }
    
    var safeCustomerAddress: String {
        customerAddress ?? ""
    }
}
