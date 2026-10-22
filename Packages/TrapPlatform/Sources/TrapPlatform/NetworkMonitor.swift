import Foundation
import Network
import Observation

/// The network path. The app has exactly one network use, the optional weather fill, and this decides whether it runs.
///
/// - `isConstrained` is Low Data Mode: no automatic fetches, manual taps still work.
/// - `isExpensive` is cellular or a personal hotspot: automatic fetches allowed (one small request), nothing else.
/// - Not reachable: the conditions fields stay editable and nothing is reported as an error.
@MainActor
@Observable
public final class NetworkMonitor {
    public private(set) var isReachable = false
    public private(set) var isExpensive = false
    public private(set) var isConstrained = false
    public private(set) var interface = "none"

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "trapshooterpro.network")

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied, expensive = path.isExpensive, constrained = path.isConstrained
            let iface = path.usesInterfaceType(.wifi) ? "wifi" : path.usesInterfaceType(.cellular) ? "cellular" : path.usesInterfaceType(.wiredEthernet) ? "wired" : reachable ? "other" : "none"
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isReachable = reachable; self.isExpensive = expensive; self.isConstrained = constrained; self.interface = iface
            }
        }
        monitor.start(queue: queue)
    }

    /// Automatic (unasked) fetches are allowed only on a reachable, unconstrained path.
    public var allowsAutomaticFetch: Bool { isReachable && !isConstrained }
    /// A manual tap may try on any reachable path, constrained or not.
    public var allowsManualFetch: Bool { isReachable }
}
