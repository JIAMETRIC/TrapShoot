import Foundation
import TrapCore

/// A request the app makes. There is one API (Open-Meteo, REST, GET, JSON, no auth) and this is all it needs.
/// There is no GraphQL, no WebSocket and no token because there is no server of our own (ADR-014).
public struct Endpoint: Equatable, Sendable {
    public let url: URL
    public var timeout: TimeInterval = 15
    public init(url: URL, timeout: TimeInterval = 15) { self.url = url; self.timeout = timeout }
    var request: URLRequest {
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        r.httpMethod = "GET"
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("TrapShooterPro iOS", forHTTPHeaderField: "User-Agent")
        return r
    }
}

public enum HTTPError: Error, Equatable, UserFacingError {
    case status(Int)
    case notHTTP
    case transport(code: Int)
    public var message: String {
        switch self {
        case .status(let s) where s == 429: return "The weather service is busy."
        case .status(let s) where s >= 500: return "The weather service is having trouble."
        case .status: return "The weather service refused the request."
        case .notHTTP, .transport: return "Could not reach the weather service."
        }
    }
    public var recovery: String? { "Check your connection, or type the values." }
    /// Worth a second try: timeouts, dropped connections, 5xx. Never 4xx, never "offline".
    public var isTransient: Bool {
        switch self {
        case .status(let s): return s >= 500 || s == 429
        case .transport(let c): return [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost].contains(c)
        case .notHTTP: return false
        }
    }
}

public protocol HTTPClient: Sendable {
    func get(_ endpoint: Endpoint) async throws -> Data
}

/// URLSession with a small retry: up to `retries` more attempts for transient failures, with 0.5 s then 1 s
/// between them. GET is idempotent, so a retry can never duplicate anything. Non-transient errors return at once.
public final class URLSessionHTTPClient: HTTPClient {
    public let session: URLSession
    public let retries: Int
    private let sleep: @Sendable (TimeInterval) async -> Void

    public init(session: URLSession = OpenMeteoClient.makeSession(), retries: Int = 2,
                sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) {
        self.session = session; self.retries = retries; self.sleep = sleep
    }

    public func get(_ endpoint: Endpoint) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await once(endpoint)
            } catch let e as HTTPError where e.isTransient && attempt < retries {
                attempt += 1
                await sleep(0.5 * Double(attempt))
            }
        }
    }

    private func once(_ endpoint: Endpoint) async throws -> Data {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: endpoint.request)
        } catch let e as URLError {
            throw HTTPError.transport(code: e.errorCode)
        }
        guard let http = response as? HTTPURLResponse else { throw HTTPError.notHTTP }
        guard (200..<300).contains(http.statusCode) else { throw HTTPError.status(http.statusCode) }
        return data
    }
}
