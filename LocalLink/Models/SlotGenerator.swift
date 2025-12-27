import Foundation

struct SlotGenerator {
    
    static func generateSlots(
        availabilityStart: Date,
        availabilityEnd: Date,
        slotMinutes: Int,
        staffId: String,
        staffName: String
    ) -> [TimeSlot] {
        
        var slots: [TimeSlot] = []
        var currentStart = availabilityStart
        
        while true {
            let currentEnd = Calendar.current.date(
                byAdding: .minute,
                value: slotMinutes,
                to: currentStart
            )!
            
            if currentEnd > availabilityEnd {
                break
            }
            
            slots.append(
                TimeSlot(
                    staffId: staffId,
                    staffName: staffName,
                    start: currentStart,
                    end: currentEnd
                )
            )
            
            currentStart = currentEnd
        }
        
        return slots
        func removeBookedSlots(
            slots: [TimeSlot],
            bookings: [Booking],
            staffId: String
        ) -> [TimeSlot] {
            
            let staffBookings = bookings.filter {
                $0.staffId == staffId && $0.status == .confirmed
            }
            
            return slots.filter { slot in
                !staffBookings.contains { booking in
                    booking.date == slot.start
                }
            }
        }
    }
}

