import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

final class BookingService {
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")
    
    // =================================================
    // CONFIRM BOOKING (PRODUCTION SAFE)
    // =================================================
    
    func confirmBooking(
        businessId: String,
        customerId: String,
        customerName: String,
        customerAddress: String,
        service: BusinessService,
        staffId: String,
        date: Date,
        startTime: Date,
        paymentIntentId: String?,
        source: String = "app",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
        guard let serviceId = service.id else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing service id."]
            )))
            return
        }
        
        // ✅ SOURCE OF TRUTH
        let durationMinutes = service.durationMinutes
        
        guard durationMinutes > 0 else {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid service duration."]
            )))
            return
        }
        
        // ✅ ALWAYS CALCULATE END TIME (DO NOT TRUST UI)
        let calculatedEnd = Calendar.current.date(
            byAdding: .minute,
            value: durationMinutes,
            to: startTime
        ) ?? startTime
        
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
        
        // =================================================
        // BUILD SLOT SEGMENTS (30 MIN GRID)
        // =================================================
        
        let slotInterval: TimeInterval = 60 * 30
        var slotTimes: [Date] = []
        var cursor = startTime
        
        while cursor < calculatedEnd {
            slotTimes.append(cursor)
            cursor = cursor.addingTimeInterval(slotInterval)
        }
        
        // Safety check
        if slotTimes.isEmpty {
            completion(.failure(NSError(
                domain: "BookingService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid slot calculation."]
            )))
            return
        }
        
        // =================================================
        // TRANSACTION
        // =================================================
        
        db.runTransaction({ txn, errorPointer -> Any? in
            
            var slotRefs: [DocumentReference] = []
            
            for slotStart in slotTimes {
                
                let slotId = SlotID.make(from: slotStart)
                let ref = slotCollection.document(slotId)
                slotRefs.append(ref)
                
                let snap: DocumentSnapshot
                
                do {
                    snap = try txn.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                
                guard snap.exists else {
                    errorPointer?.pointee = NSError(
                        domain: "BookingService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Slot does not exist."]
                    )
                    return nil
                }
                
                if (snap.data()?["isBooked"] as? Bool) == true {
                    errorPointer?.pointee = NSError(
                        domain: "BookingService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Time already booked."]
                    )
                    return nil
                }
            }
            
            // =================================================
            // CREATE BOOKING
            // =================================================
            
            txn.setData([
                "businessId": businessId,
                "customerId": customerId,
                
                "serviceId": serviceId,
                "serviceName": service.name,
                "serviceDurationMinutes": durationMinutes,
                
                "price": pricePence,
                
                "staffId": staffId,
                "staffName": "",
                
                "customerName": customerName,
                "customerAddress": customerAddress,
                
                "paymentIntentId": paymentIntentId ?? "",
                
                "bookingDay": Timestamp(date: bookingDay),
                "date": Timestamp(date: bookingDay),
                
                "startDate": Timestamp(date: startTime),
                "endDate": Timestamp(date: calculatedEnd),
                
                "status": BookingStatus.confirmed.rawValue,
                "source": source,
                
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: bookingRef)
            
            // =================================================
            // LOCK ALL REQUIRED SLOTS
            // =================================================
            
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
    // CANCEL BOOKING (UNIFIED – CUSTOMER + BUSINESS)
    // =================================================
    
    func cancelBooking(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
        functions.httpsCallable("cancelBooking").call([
            "bookingId": bookingId
        ]) { result, error in
            
            DispatchQueue.main.async {
                
                if let error {
                    completion(.failure(error))
                    return
                }
                
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
                "status": "completed"
            ]) { error in
                
                DispatchQueue.main.async {
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
}
