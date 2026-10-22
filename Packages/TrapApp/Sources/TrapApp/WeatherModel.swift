import Foundation
import Observation
import TrapCore
import TrapPlatform
import TrapWeather

/// The optional weather fill (the app's only network call). Expected failures are states with a line of text,
/// never alerts (CLAUDE.md rule 11); the conditions stay editable whatever happens.
@MainActor
@Observable
final class WeatherModel {
    enum State: Equatable { case idle, fetching, filled(String), failed(String) }
    private(set) var state: State = .idle
    /// Round ids the automatic fill already tried, so it runs once per round.
    @ObservationIgnored private var tried: Set<String> = []
    @ObservationIgnored private let service: WeatherService
    @ObservationIgnored private var location: LocationOnce?

    init(service: WeatherService = OpenMeteoClient()) { self.service = service }

    /// Automatic fill when a round is opened: once, before the first target, empty conditions, unconstrained network.
    func autoFill(_ record: RecordModel, enabled: Bool, network: NetworkMonitor) {
        let r = record.round
        guard WeatherFill.shouldAutoFill(round: r, enabled: enabled, started: r.hasData, alreadyTried: tried.contains(r.id),
                                         networkAllowsAutomatic: network.allowsAutomaticFetch) else { return }
        tried.insert(r.id)
        Task { await fill(record, manual: false) }
    }

    /// The Weather button. Overwrites the conditions with what the service reports.
    func manualFill(_ record: RecordModel, network: NetworkMonitor) {
        guard network.allowsManualFetch else { state = .failed("No connection. Type the values."); return }
        Task { await fill(record, manual: true) }
    }

    private func fill(_ record: RecordModel, manual: Bool) async {
        state = .fetching
        let id = record.round.id
        do {
            let loc = location ?? LocationOnce()
            location = loc
            let here = try await loc.fetch()
            let sample = try await service.current(latitude: here.latitude, longitude: here.longitude)
            guard record.round.id == id else { state = .idle; return }
            record.updateSetup { r in _ = WeatherFill.apply(sample, to: &r, manual: manual) }
            state = .filled(WeatherFill.summary(sample, at: DateText.hourMinute(Date())))
        } catch {
            TrapLog.network.info("weather fill failed: \(String(describing: error), privacy: .public)")
            let e = DisplayError(any: error, fallback: "Could not get the weather.")
            state = manual ? .failed(e.text) : .idle
        }
    }
}
