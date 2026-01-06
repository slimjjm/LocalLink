import Foundation
import FirebaseFirestore

// MARK: - Booking Availability Validator

struct BookingAvailabilityValidator {

    // MARK: - Errors

    enum ValidationError: LocalizedError {
        case staffInactive
        case serviceInactive
        case dayClosed
        case outsideWorkingHours
        case overlapsExistingBooking

        var errorDescription: String? {
            switch self {
            case .staffInactive:
                return "This staff member is not currently active."
            case .serviceInactive:
                return "This service is no longer available."
            case .dayClosed:
                return "This staff member does not work on this day."
            case .outsideWorkingHours:
                return "This time is outside working hours."
            case .overlapsExistingBooking:
                return "This time slot has just been booked."
            }
        }
    }

    // MARK: - Public API

    static func validate(
        staff: Staff,
        availability: EditableWeeklyAvailability,
        bookings: [Booking],
        selectedDate: Date,
        serviceDurationMinutes: Int
    ) throws {

        // 1️⃣ Staff must be active
        guard staff.isActive else {
            throw ValidationError.staffInactive
        }

        // 2️⃣ Resolve weekday availability
        let weekday = selectedDate.weekdayKey
        let dayAvailability = availability.day(for: weekday)

        guard !dayAvailability.closed else {
            throw ValidationError.dayClosed
        }

        // 3️⃣ Validate working hours
        let startTime = dayAvailability.open
        let endTime = dayAvailability.close

        let bookingStart = selectedDate
        let bookingEnd = selectedDate.addingTimeInterval(
            TimeInterval(serviceDurationMinutes * 60)
        )

        let dayStart = bookingStart.settingTime(from: startTime)
        let dayEnd = bookingStart.settingTime(from: endTime)

        guard bookingStart >= dayStart && bookingEnd <= dayEnd else {
            throw ValidationError.outsideWorkingHours
        }

        // 4️⃣ Check overlaps
        for booking in bookings {
            let existingStart = booking.date
            let existingEnd = booking.date.addingTimeInterval(
                TimeInterval(serviceDurationMinutes * 60)
            )

            let overlaps =
                bookingStart < existingEnd &&
                bookingEnd > existingStart

            if overlaps {
                throw ValidationError.overlapsExistingBooking
            }
        }
    }
}

