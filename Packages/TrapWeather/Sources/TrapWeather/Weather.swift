import Foundation
import TrapCore

/// Sky as the round stores it.
public enum Sky: String, CaseIterable, Sendable {
    case sun, part, overcast, rain
    public var name: String {
        switch self { case .sun: return "Sun"; case .part: return "Part cloud"; case .overcast: return "Overcast"; case .rain: return "Rain" }
    }
}

/// Wind as the round stores it.
public enum Wind: String, CaseIterable, Sendable {
    case calm, light, moderate, strong
    public var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// The current conditions as Open-Meteo reports them.
public struct WeatherSample: Equatable, Sendable {
    public var temperatureC: Double?
    public var humidityPct: Double?
    public var precipitationMm: Double?
    public var weatherCode: Int?
    public var cloudCoverPct: Double?
    public var windKmh: Double?
    public init(temperatureC: Double? = nil, humidityPct: Double? = nil, precipitationMm: Double? = nil, weatherCode: Int? = nil, cloudCoverPct: Double? = nil, windKmh: Double? = nil) {
        self.temperatureC = temperatureC; self.humidityPct = humidityPct; self.precipitationMm = precipitationMm
        self.weatherCode = weatherCode; self.cloudCoverPct = cloudCoverPct; self.windKmh = windKmh
    }

    /// Rain when it is raining or the WMO code says drizzle, rain, snow, showers or thunder; otherwise by cloud cover.
    public var sky: Sky? {
        let code = weatherCode ?? -1
        let rain = (precipitationMm ?? 0) > 0 || (51...67).contains(code) || (71...77).contains(code) || (80...86).contains(code) || code >= 95
        if rain { return .rain }
        guard let cc = cloudCoverPct else { return nil }
        return cc < 25 ? .sun : cc < 70 ? .part : .overcast
    }

    /// Beaufort-ish bands in km/h: under 6 calm, under 20 light, under 39 moderate, else strong.
    public var wind: Wind? {
        guard let k = windKmh else { return nil }
        return k < 6 ? .calm : k < 20 ? .light : k < 39 ? .moderate : .strong
    }
}

/// Puts a sample into a round. Manual (the shooter tapped the button) replaces every value;
/// automatic fills empty fields only. Returns true when anything changed.
public enum WeatherFill {
    @discardableResult
    public static func apply(_ c: WeatherSample, to r: inout Round, manual: Bool) -> Bool {
        var changed = false
        if let t = c.temperatureC, manual || r.temperature == nil { r.temperature = jsRound(t); changed = true }
        if let h = c.humidityPct, manual || r.humidity == nil { r.humidity = jsRound(h); changed = true }
        if let s = c.sky, manual || r.sky.isEmpty { r.sky = s.rawValue; changed = true }
        if let w = c.wind, manual || r.wind.isEmpty { r.wind = w.rawValue; changed = true }
        return changed
    }

    /// "Filled from your location at 09:41: Sun, 24°C, 55% humidity, wind 12 km/h. Change any value you like."
    public static func summary(_ c: WeatherSample, at time: String) -> String {
        var bits: [String] = []
        if let s = c.sky { bits.append(s.name) }
        if let t = c.temperatureC { bits.append("\(Int(jsRound(t)))°C") }
        if let h = c.humidityPct { bits.append("\(Int(jsRound(h)))% humidity") }
        if let w = c.windKmh { bits.append("wind \(Int(jsRound(w))) km/h") }
        return "Filled from your location at \(time): " + bits.joined(separator: ", ") + ". Change any value you like."
    }

    /// The page's `autoWeather` rule plus the network policy: once per round, only before the first target,
    /// only when the conditions are still empty, never on a constrained path.
    public static func shouldAutoFill(round r: Round, enabled: Bool, started: Bool, alreadyTried: Bool, networkAllowsAutomatic: Bool) -> Bool {
        guard enabled, !started, !alreadyTried, networkAllowsAutomatic else { return false }
        return r.temperature == nil && r.humidity == nil && r.sky.isEmpty
    }

    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
}

public enum WeatherError: Error, Equatable {
    case badURL
    case httpStatus(Int)
    case noData
    case locationDenied
    case locationUnavailable
    case timeout
}

/// Anything that can answer "what is the weather here".
public protocol WeatherService: Sendable {
    func current(latitude: Double, longitude: Double) async throws -> WeatherSample
}

/// Open-Meteo, no key, one request. The session is tuned for a phone on a range:
/// 15 s timeout, no waiting for connectivity, no cache, no cookies, no constrained (Low Data Mode) access.
public final class OpenMeteoClient: WeatherService {
    public static let endpoint = "https://api.open-meteo.com/v1/forecast"
    private let session: URLSession

    public init(session: URLSession = OpenMeteoClient.makeSession()) { self.session = session }

    public static func makeSession(allowConstrained: Bool = false) -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 20
        c.waitsForConnectivity = false
        c.allowsConstrainedNetworkAccess = allowConstrained
        c.allowsExpensiveNetworkAccess = true
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: c)
    }

    /// Same query as the 7.x page, so the answer is the same answer.
    public static func url(latitude: Double, longitude: Double) -> URL? {
        var comps = URLComponents(string: endpoint)
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return comps?.url
    }

    public func current(latitude: Double, longitude: Double) async throws -> WeatherSample {
        guard let url = OpenMeteoClient.url(latitude: latitude, longitude: longitude) else { throw WeatherError.badURL }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw WeatherError.httpStatus(http.statusCode) }
        return try OpenMeteoClient.parse(data)
    }

    public static func parse(_ data: Data) throws -> WeatherSample {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let c = root["current"] as? [String: Any] else { throw WeatherError.noData }
        func num(_ k: String) -> Double? { (c[k] as? NSNumber)?.doubleValue }
        return WeatherSample(temperatureC: num("temperature_2m"), humidityPct: num("relative_humidity_2m"), precipitationMm: num("precipitation"),
                             weatherCode: num("weather_code").map { Int($0) }, cloudCoverPct: num("cloud_cover"), windKmh: num("wind_speed_10m"))
    }
}
