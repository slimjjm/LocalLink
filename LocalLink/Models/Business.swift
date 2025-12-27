import Foundation
import CoreLocation

struct Business: Identifiable {
    var id: String
    var name: String
    var openingHours: String
    var contactNumber: String
    var logoURL: String
    var latitude: Double
    var longitude: Double
}
