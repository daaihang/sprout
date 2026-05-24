import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.mory", category: "network")

/// Lightweight NWPathMonitor wrapper that tracks whether the device has a usable network path.
///
/// Use `NetworkReachabilityMonitor.shared.isConnected` as a fast best-effort check before
/// dispatching network requests. The monitor does **not** hard-block requests — all actual
/// error handling still goes through URLSession, but this allows UI to surface a clear
/// "You appear to be offline" message instead of waiting for a timeout.
///
/// Example:
/// ```swift
/// if !NetworkReachabilityMonitor.shared.isConnected {
///     // show offline banner or skip request
/// }
/// ```
@MainActor
final class NetworkReachabilityMonitor {
    static let shared = NetworkReachabilityMonitor()

    /// `true` when NWPathMonitor reports `.satisfied`; `false` when offline or unknown.
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "dev.mory.network.reachability", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isConnected != connected else { return }
                self.isConnected = connected
                log.info("Network reachability changed: \(connected ? "online" : "offline", privacy: .public)")
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
