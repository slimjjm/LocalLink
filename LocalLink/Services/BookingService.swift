import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class BookingService {

    private let db = Firestore.firestore()
    private let bookingRepo = BookingRepository()
    private let functions = Functions.functions(region: "us-central1")

    // MARK: - Confirm Booking

    func confirmBooking(
        businessId: String,
        customerId: String,
        customerName: String,
        customerAddress: String,
        service: BusinessService,
        staff: Staff,
        location: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        paymentIntentId: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard paymentIntentId != nil else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 402,
                userInfo: [NSLocalizedDescriptionKey: "Payment required before booking."]
            )))
            return
        }
        guard
            let serviceId = service.id,
            let staffId = staff.id
        else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing service or staff ID."]
            )))
            return
        }

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .whereField("startDate", isEqualTo: Timestamp(date: startTime))
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                if let snapshot, !snapshot.documents.isEmpty {
                    completion(.failure(NSError(
                        domain: "BookingService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "This time slot has just been booked."]
                    )))
                    return
                }

                let booking = Booking(
                    businessId: businessId,
                    customerId: customerId,
                    ownerId: "",
                    location: location, // 👈 service area (NOT the customer address)
                    serviceId: serviceId,
                    serviceName: service.name,
                    serviceDurationMinutes: service.durationMinutes,
                    price: service.price,
                    staffId: staffId,
                    staffName: staff.name,
                    customerName: customerName, // 👈 now correctly saved
                    customerAddress: customerAddress, // 👈 permanently stored
                    paymentIntentId: paymentIntentId ?? "",
                    refundId: nil,
                    refundedAt: nil,
                    date: date,
                    startDate: startTime,
                    endDate: endTime,
                    status: .confirmed,
                    createdAt: Date()
                )

                self.bookingRepo.createBooking(booking, completion: completion)
            }
    }

    // MARK: - Cancel (Customer via Cloud Function)

    func cancelBookingAsCustomer(
        booking: Booking,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let bookingId = booking.id else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing booking id."]
            )))
            return
        }

        functions.httpsCallable("refundBooking")
            .call(["bookingId": bookingId]) { _, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }

    // MARK: - Cancel (Business)

    func cancelBookingAsBusiness(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.cancelledByBusiness.rawValue
            ]) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }

    // MARK: - Complete

    func markBookingAsCompleted(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.completed.rawValue
            ]) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}

