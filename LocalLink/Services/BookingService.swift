import Foundation

final class BookingService {

    private let bookingRepo = BookingRepository()

    // MARK: - Confirm Booking
    func confirmBooking(
        businessId: String,
        customerId: String,
        service: BusinessService,
        staff: Staff,
        date: Date,
        startTime: Date,
        endTime: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

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

            date: date,
            startDate: startTime,
            endDate: endTime,

            status: .confirmed,
            createdAt: Date()
        )

        bookingRepo.createBooking(booking, completion: completion)
    }

    // MARK: - Cancel (Customer)
    func cancelBookingAsCustomer(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        bookingRepo.cancelBookingByCustomer(
            bookingId: bookingId,
            completion: completion
        )
    }

    // MARK: - Cancel (Business)
    func cancelBookingAsBusiness(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        bookingRepo.cancelBookingByBusiness(
            bookingId: bookingId,
            completion: completion
        )
    }
}
