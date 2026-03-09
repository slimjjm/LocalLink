import Foundation
import MapKit

struct AddressResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D?
}

final class AddressSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published var results: [AddressResult] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()

        completer.delegate = self
        completer.resultTypes = .address

        // 🇬🇧 Restrict to UK region (rough bounding box)
        let ukRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 54.5, longitude: -3),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        completer.region = ukRegion
    }

    func update(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    func clear() {
        results = []
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {

        results = completer.results.map {
            AddressResult(
                title: $0.title,
                subtitle: $0.subtitle,
                coordinate: nil
            )
        }
    }

    func resolveCoordinate(for result: AddressResult) async -> CLLocationCoordinate2D? {

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "\(result.title), \(result.subtitle)"

        let search = MKLocalSearch(request: searchRequest)

        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }
}
