import Foundation
import MapKit

final class AddressSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    
    @Published var query: String = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
        }
    }
    
    func clearResults() {
        results = []
    }
}
