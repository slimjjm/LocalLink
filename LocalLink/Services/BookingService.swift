import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class BookingService {

    private let db = Firestore.firestore()
    private let bookingRepo = BookingRepository()
    private let functions = Functions.functions(region: "us-central1")

    // =================================================
    // CONFIRM BOOKING
    // =================================================
    func confirmBooking(
        businessId: String,
        customerId: String,
        customerName: String,
        customerAddress: String,
        service: BusinessService,
        staff: Staff,
        date: Date,
        startTime: Date,
        endTime: Date,
        paymentIntentId: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        let pi = (paymentIntentId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pi.isEmpty else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 402,
                userInfo: [NSLocalizedDescriptionKey: "Payment required before booking."]
            )))
            return
        }

        guard let serviceId = service.id,
              let staffId = staff.id else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing service or staff ID."]
            )))
            return
        }

        guard endTime > startTime else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid time range."]
            )))
            return
        }

        let bookingDay = date.localMidnight()

        // -------------------------------------------------
        // COLLISION CHECK (quick guard: exact start already booked)
        // NOTE: This is a lightweight guard. Slot-level booking is handled below.
        // -------------------------------------------------
        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("staffId", isEqualTo: staffId)
            .whereField("startDate", isEqualTo: Timestamp(date: startTime))
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .limit(to: 1)
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
                        userInfo: [NSLocalizedDescriptionKey: "Slot just booked."]
                    )))
                    return
                }

                let booking = Booking(
                    businessId: businessId,
                    customerId: customerId,
                    ownerId: "",
                    serviceId: serviceId,
                    serviceName: service.name,
                    serviceDurationMinutes: service.durationMinutes,
                    price: Int((service.price * 100).rounded()), // pence
                    staffId: staffId,
                    staffName: staff.name,
                    customerName: customerName,
                    customerAddress: customerAddress,
                    paymentIntentId: pi,
                    refundId: nil,
                    refundedAt: nil,
                    isPaid: true,
                    bookingDay: bookingDay,
                    date: bookingDay,
                    startDate: startTime,
                    endDate: endTime,
                    status: .confirmed,
                    createdAt: Date()
                )

                // -------------------------------------------------
                // CREATE BOOKING
                // -------------------------------------------------
                self.bookingRepo.createBooking(booking) { result in
                    switch result {

                    case .failure(let error):
                        completion(.failure(error))

                    case .success:

                        guard let bookingId = booking.id else {
                            completion(.success(()))
                            return
                        }

                        // -------------------------------------------------
                        // MARK *ALL* OVERLAPPING SLOTS AS BOOKED
                        // booking: startTime -> endTime (e.g. 60 mins)
                        // slots: 30-min increments (e.g. 11:00 & 11:30)
                        // -------------------------------------------------
                        let slotsRef = self.db
                            .collection("businesses")
                            .document(businessId)
                            .collection("staff")
                            .document(staffId)
                            .collection("availableSlots")

                        slotsRef
                            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startTime))
                            .whereField("startTime", isLessThan: Timestamp(date: endTime))
                            .getDocuments { snap, err in

                                if let err {
                                    completion(.failure(err))
                                    return
                                }

                                let docs = snap?.documents ?? []
                                guard !docs.isEmpty else {
                                    // Booking exists, but slot docs not found (e.g. availability not generated)
                                    completion(.success(()))
                                    return
                                }

                                let pricePence = Int((service.price * 100).rounded())
                                let batch = self.db.batch()

                                for doc in docs {
                                    batch.updateData([
                                        "isBooked": true,
                                        "bookingId": bookingId,
                                        // Store the booking price so your dashboard math can read slot revenue
                                        "price": pricePence
                                    ], forDocument: doc.reference)
                                }

                                batch.commit { commitErr in
                                    if let commitErr {
                                        completion(.failure(commitErr))
                                    } else {
                                        completion(.success(()))
                                    }
                                }
                            }
                    }
                }
            }
    }

    // =================================================
    // CUSTOMER CANCEL → CLOUD FUNCTION REFUND
    // =================================================
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

    // =================================================
    // BUSINESS CANCEL
    // =================================================
    func cancelBookingAsBusiness(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.cancelledByBusiness.rawValue
            ]) { error in
                if let error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
    }

    // =================================================
    // MANUAL COMPLETE
    // =================================================
    func markBookingAsCompleted(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.completed.rawValue
            ]) { error in
                if let error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
    }
}
