// Models/StaffEditableDay.swift
import Foundation

struct StaffEditableDay: Identifiable {

    let key: DayKey

    var closed: Bool
    var openTime: Date
    var closeTime: Date

    var id: String { key.rawValue }
}
