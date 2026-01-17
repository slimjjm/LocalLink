import Foundation
import FirebaseFirestore

final class BookingService {

    // MARK: - Dependencies
    private let db = Firestore.firestore()
    private let bookingRepo = BookingRepository()

    // MARK: - Confirm Booking (Collision-safe + Rule-safe)
    func confirmBooking(
        businessId: String,
        customerId: String,
        service: BusinessService,
        staff: Staff,
        location: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        // Validate required IDs
        guard
            let serviceId = service.id,
            let staffId = staff.id
        else {
            completion(
                .failure(
                    NSError(
                        domain: "BookingService",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Missing service or staff ID."
                        ]
                    )
                )
            )
            return
        }

        // -----------------------------------------
        // STEP 1: Prevent double-booking (collision)
        // -----------------------------------------
        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .whereField("startDate", isEqualTo: startTime)
            .whereField("status", isEqualTo: "confirmed")
            .getDocuments { snapshot, error in

                if let error {
                    completion(.failure(error))
                    return
                }

                // Slot already taken
                if let snapshot, !snapshot.documents.isEmpty {
                    completion(
                        .failure(
                            NSError(
                                domain: "BookingService",
                                code: 409,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "This time slot has just been booked. Please choose another time."
                                ]
                            )
                        )
                    )
                    return
                }

                // -----------------------------------------
                // STEP 2: Fetch business ownerId
                // -----------------------------------------
                self.db.collection("businesses")
                    .document(businessId)
                    .getDocument { businessSnap, error in

                        if let error {
                            completion(.failure(error))
                            return
                        }

                        guard
                            let data = businessSnap?.data(),
                            let ownerId = data["ownerId"] as? String
                        else {
                            completion(
                                .failure(
                                    NSError(
                                        domain: "BookingService",
                                        code: 0,
                                        userInfo: [
                                            NSLocalizedDescriptionKey:
                                                "Unable to determine business owner."
                                        ]
                                    )
                                )
                            )
                            return
                        }

                        // -----------------------------------------
                        // STEP 3: Create booking (rule-compliant)
                        // -----------------------------------------
                        let booking = Booking(
                            businessId: businessId,
                            customerId: customerId,
                            location: location,
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


                        // -----------------------------------------
                        // STEP 4: Persist
                        // -----------------------------------------
                        self.bookingRepo.createBooking(
                            booking,
                            completion: completion
                        )
                    }
            }
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
