import CoreLocation
import Foundation

/// One location, once per round, kilometre accuracy, 25 s limit. The port of 7.0.7's `LocationFetcher`.
/// Permission is "when in use" and is asked the first time the shooter (or the auto-fill) wants the weather.
@MainActor
public final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<CLLocationCoordinate2D, Error>] = []
    private var timeoutTask: Task<Void, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public var isDenied: Bool { manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted }

    public func fetch(timeout seconds: Double = 25) async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { cont in
            waiting.append(cont)
            if waiting.count == 1 {
                timeoutTask?.cancel()
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(seconds))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(WeatherError.timeout))
                }
            }
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .denied, .restricted: finish(.failure(WeatherError.locationDenied))
            default: manager.requestLocation()
            }
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, !self.waiting.isEmpty else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.finish(.failure(WeatherError.locationDenied))
            default: break
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let c = last.coordinate
        Task { @MainActor [weak self] in self?.finish(.success(c)) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.finish(.failure(WeatherError.locationUnavailable)) }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        timeoutTask?.cancel(); timeoutTask = nil
        let list = waiting
        waiting = []
        for c in list { c.resume(with: result) }
    }
}
