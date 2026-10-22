import CoreLocation

/// One-off location for the weather fill on Range data and conditions.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    typealias Done = (Double?, Double?, String?) -> Void
    private let manager = CLLocationManager()
    private var waiting: [Done] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetch(_ done: @escaping Done) {
        waiting.append(done)
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(nil, nil, "denied")
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !waiting.isEmpty else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(nil, nil, "denied")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last {
            finish(last.coordinate.latitude, last.coordinate.longitude, nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil, nil, "unavailable")
    }

    private func finish(_ lat: Double?, _ lon: Double?, _ err: String?) {
        let callbacks = waiting
        waiting = []
        DispatchQueue.main.async { callbacks.forEach { $0(lat, lon, err) } }
    }
}
