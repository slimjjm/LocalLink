import Foundation

final class StaffAvailabilityEngine {

    func loadAvailableSlots(
        businessId: String,
        service: BusinessService,
        date: Date,
        completion: @escaping ([StaffSlot]) -> Void
    ) {
        // STUB — real logic comes later
        completion([])
    }
}

