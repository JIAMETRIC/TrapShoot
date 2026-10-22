import XCTest
@testable import TrapWeather

/// Answers every request from a script. Integration tests of the client without the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var script: [(status: Int, body: Data)] = []
    nonisolated(unsafe) static var failures: [URLError.Code] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []
    static func reset() { script = []; failures = []; requests = [] }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        StubURLProtocol.requests.append(request)
        if !StubURLProtocol.failures.isEmpty {
            client?.urlProtocol(self, didFailWithError: URLError(StubURLProtocol.failures.removeFirst()))
            return
        }
        let step = StubURLProtocol.script.isEmpty ? (status: 200, body: Data()) : StubURLProtocol.script.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: step.status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: step.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class HTTPClientTests: XCTestCase {
    private var sleeps: [TimeInterval] = []

    private func client(retries: Int = 2) -> URLSessionHTTPClient {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [StubURLProtocol.self]
        sleeps = []
        return URLSessionHTTPClient(session: URLSession(configuration: c), retries: retries, sleep: { _ in })
    }

    override func setUp() { StubURLProtocol.reset() }

    func testSuccessAndHeaders() async throws {
        StubURLProtocol.script = [(200, Data(#"{"current":{"temperature_2m":20}}"#.utf8))]
        let data = try await client().get(Endpoint(url: URL(string: "https://example.test/x")!))
        XCTAssertEqual(try OpenMeteoClient.parse(data).temperatureC, 20)
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(StubURLProtocol.requests.first?.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testRetriesTransientThenSucceeds() async throws {
        StubURLProtocol.script = [(503, Data()), (200, Data("{}".utf8))]
        _ = try await client().get(Endpoint(url: URL(string: "https://example.test/x")!))
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
    }

    func testDoesNotRetryClientErrors() async {
        StubURLProtocol.script = [(404, Data())]
        do { _ = try await client().get(Endpoint(url: URL(string: "https://example.test/x")!)); XCTFail("expected error") }
        catch { XCTAssertEqual(error as? HTTPError, .status(404)); XCTAssertEqual(StubURLProtocol.requests.count, 1) }
    }

    func testGivesUpAfterRetries() async {
        StubURLProtocol.script = [(500, Data()), (500, Data()), (500, Data()), (200, Data())]
        do { _ = try await client(retries: 2).get(Endpoint(url: URL(string: "https://example.test/x")!)); XCTFail("expected error") }
        catch { XCTAssertEqual(error as? HTTPError, .status(500)); XCTAssertEqual(StubURLProtocol.requests.count, 3) }
    }

    func testTransportErrorsMapAndRetry() async {
        StubURLProtocol.failures = [.timedOut]
        StubURLProtocol.script = [(200, Data("{}".utf8))]
        do { _ = try await client().get(Endpoint(url: URL(string: "https://example.test/x")!)) } catch { XCTFail("\(error)") }
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertTrue(HTTPError.transport(code: NSURLErrorTimedOut).isTransient)
        XCTAssertFalse(HTTPError.transport(code: NSURLErrorNotConnectedToInternet).isTransient, "offline is not retried")
        XCTAssertEqual(HTTPError.status(429).message, "The weather service is busy.")
    }

    func testOpenMeteoThroughTheStub() async throws {
        StubURLProtocol.script = [(200, Data(#"{"current":{"temperature_2m":27.2,"relative_humidity_2m":61,"precipitation":0.4,"weather_code":61,"cloud_cover":90,"wind_speed_10m":25}}"#.utf8))]
        let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [StubURLProtocol.self]
        let s = try await OpenMeteoClient(http: URLSessionHTTPClient(session: URLSession(configuration: c), retries: 0, sleep: { _ in })).current(latitude: 25, longitude: 55)
        XCTAssertEqual(s.sky, .rain); XCTAssertEqual(s.wind, .moderate)
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.host, "api.open-meteo.com")
    }
}
