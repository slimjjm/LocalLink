import Foundation

final class BookingService {

    private let bookingRepo = BookingRepository()

    func confirmBooking(
        businessId: String,
        customerId: String,
        service: Service,
        staff: Staff,
        date: Date,
        startTime: Date,
        endTime: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        // 🔒 Hard safety: IDs MUST exist at this point
        guard
            let serviceId = service.id,
            let staffId = staff.id
        else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing service or staff ID"]
            )))
            return
        }

        let booking = Booking(
            businessId: businessId,
            customerId: customerId,

            serviceId: serviceId,
            serviceName: service.name,
            serviceDurationMinutes: service.durationMinutes,
            price: service.price,

            staffId: staffId,
            staffName: staff.name,

            date: date,                 // booking day
            startDate: startTime,       // booking start
            endDate: endTime,           // booking end

            status: .confirmed,
            createdAt: Date()
        )

        bookingRepo.createBooking(booking, completion: completion)
    }
}
