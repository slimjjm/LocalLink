import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

final class BookingService {

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    // =================================================
    // CONFIRM BOOKING (transaction-safe)
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
        source: String = "app", // 👈 NEW
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        guard let serviceId = service.id,
              let staffId = staff.id else { return }

        let bookingDay = date.localMidnight()
        let pricePence = Int((service.price * 100).rounded())

        let slotCollection = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availableSlots")

        let bookingRef = db.collection("bookings").document()
        let bookingId = bookingRef.documentID

        let interval: TimeInterval = 60 * 30
        var slotTimes: [Date] = []
        var cursor = startTime

        while cursor < endTime {
            slotTimes.append(cursor)
            cursor = cursor.addingTimeInterval(interval)
        }

        let formatter = ISO8601DateFormatter()

        db.runTransaction({ txn, errorPointer -> Any? in

            var slotRefs: [DocumentReference] = []

            for slotStart in slotTimes {

                let slotId = formatter.string(from: slotStart)
                let ref = slotCollection.document(slotId)
                slotRefs.append(ref)

                let snap: DocumentSnapshot

                do {
                    snap = try txn.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                // ❗ SLOT MUST EXIST
                guard snap.exists else {

                    errorPointer?.pointee = NSError(
                        domain: "BookingService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey:
                                   "Slot does not exist"]
                    )
                    return nil
                }

                if (snap.data()?["isBooked"] as? Bool) == true {

                    errorPointer?.pointee = NSError(
                        domain: "BookingService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey:
                                   "Slot already booked"]
                    )
                    return nil
                }
            }

            txn.setData([

                "businessId": businessId,
                "customerId": customerId,

                "serviceId": serviceId,
                "serviceName": service.name,
                "serviceDurationMinutes": service.durationMinutes,

                "price": pricePence,

                "staffId": staffId,
                "staffName": staff.name,

                "customerName": customerName,
                "customerAddress": customerAddress,

                "paymentIntentId": paymentIntentId ?? "",

                "bookingDay": Timestamp(date: bookingDay),
                "date": Timestamp(date: bookingDay),

                "startDate": Timestamp(date: startTime),
                "endDate": Timestamp(date: endTime),

                "status": BookingStatus.confirmed.rawValue,

                "source": source, // 👈 NEW

                "createdAt": FieldValue.serverTimestamp()

            ], forDocument: bookingRef)

            for ref in slotRefs {
                txn.setData([
                    "isBooked": true,
                    "bookingId": bookingId
                ], forDocument: ref, merge: true)
            }

            return nil

        }) { _, error in

            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // =================================================
    // CUSTOMER CANCEL
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
                "status": BookingStatus.cancelledByBusiness.rawValue,
                "cancelledAt": FieldValue.serverTimestamp()
            ]) { error in

                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }

    // =================================================
    // MARK COMPLETE
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

                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}
