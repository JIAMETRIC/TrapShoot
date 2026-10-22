import Foundation
import Observation
import UIKit

/// Battery, Low Power Mode and thermal state, with one piece of advice the screens can act on.
///
/// What the timer costs: the audio engine runs in `.measurement` mode with 5 ms buffers and the screen stays on.
/// That is the single biggest battery draw in the app, so the advice is about the timer:
/// - **conserve**: slow the level meter (5 Hz instead of 20), do not suggest round audio, dim nothing else.
/// - **critical**: say so before Start; the shooter decides.
@MainActor
@Observable
public final class PowerMonitor {
    public enum Advice: Equatable, Sendable {
        case normal
        case conserve(String)
        case critical(String)
        public var isConserving: Bool { if case .normal = self { return false }; return true }
        public var message: String? {
            switch self { case .normal: return nil; case .conserve(let m), .critical(let m): return m }
        }
    }

    public private(set) var batteryLevel: Float = -1
    public private(set) var batteryState: UIDevice.BatteryState = .unknown
    public private(set) var isLowPowerMode = false
    public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    public private(set) var advice: Advice = .normal

    /// Level-meter refresh the Timer screen should use.
    public var levelMeterHz: Double { advice.isConserving ? 5 : 20 }
    /// Whether to pre-tick "Record round audio" for a new session.
    public var suggestRoundAudio: Bool { !advice.isConserving }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    public init(device: UIDevice = .current, processInfo: ProcessInfo = .processInfo) {
        device.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh(device: device, processInfo: processInfo) }
            })
        }
        refresh(device: device, processInfo: processInfo)
    }

    public func refresh(device: UIDevice = .current, processInfo: ProcessInfo = .processInfo) {
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
        isLowPowerMode = processInfo.isLowPowerModeEnabled
        thermalState = processInfo.thermalState
        advice = PowerMonitor.advice(level: batteryLevel, state: batteryState, lowPower: isLowPowerMode, thermal: thermalState)
    }

    /// Pure, so it is testable.
    public static func advice(level: Float, state: UIDevice.BatteryState, lowPower: Bool, thermal: ProcessInfo.ThermalState) -> Advice {
        if thermal == .critical { return .critical("The phone is too hot. Let it cool before timing; the microphone may be throttled.") }
        let charging = state == .charging || state == .full
        if !charging, level >= 0, level < 0.10 { return .critical("Battery under 10 %. Plug in, or expect timing to stop when the phone shuts down.") }
        if thermal == .serious { return .conserve("The phone is hot. The level meter updates less often until it cools.") }
        if lowPower { return .conserve("Low Power Mode is on. The level meter updates less often; round audio is off by default.") }
        if !charging, level >= 0, level < 0.20 { return .conserve("Battery under 20 %. Round audio is off by default.") }
        return .normal
    }
}
