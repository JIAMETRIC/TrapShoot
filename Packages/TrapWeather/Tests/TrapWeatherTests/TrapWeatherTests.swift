import XCTest
import TrapCore
@testable import TrapWeather

final class TrapWeatherTests: XCTestCase {
    func testSkyAndWindMatchWebApp() {
        // skyFrom: rain by precipitation or WMO code, then cloud cover bands
        XCTAssertEqual(WeatherSample(precipitationMm: 0.2, cloudCoverPct: 10).sky, .rain)
        for code in [51, 67, 71, 77, 80, 86, 95, 99] { XCTAssertEqual(WeatherSample(weatherCode: code, cloudCoverPct: 0).sky, .rain, "code \(code)") }
        for code in [0, 3, 45, 48, 50, 68, 70, 78, 79, 87, 94] { XCTAssertNotEqual(WeatherSample(weatherCode: code, cloudCoverPct: 0).sky, .rain, "code \(code)") }
        XCTAssertNil(WeatherSample(weatherCode: 1).sky)
        XCTAssertEqual(WeatherSample(cloudCoverPct: 24.9).sky, .sun)
        XCTAssertEqual(WeatherSample(cloudCoverPct: 25).sky, .part)
        XCTAssertEqual(WeatherSample(cloudCoverPct: 69.9).sky, .part)
        XCTAssertEqual(WeatherSample(cloudCoverPct: 70).sky, .overcast)
        // windFrom
        XCTAssertNil(WeatherSample().wind)
        XCTAssertEqual(WeatherSample(windKmh: 5.9).wind, .calm)
        XCTAssertEqual(WeatherSample(windKmh: 6).wind, .light)
        XCTAssertEqual(WeatherSample(windKmh: 19.9).wind, .light)
        XCTAssertEqual(WeatherSample(windKmh: 20).wind, .moderate)
        XCTAssertEqual(WeatherSample(windKmh: 38.9).wind, .moderate)
        XCTAssertEqual(WeatherSample(windKmh: 39).wind, .strong)
    }

    func testFillManualAndAutomatic() {
        var r = Round(id: "r", createdAt: "", date: "2026-10-22", startTime: "09:00")
        r.temperature = 30; r.sky = "sun"
        let c = WeatherSample(temperatureC: 23.6, humidityPct: 54.5, precipitationMm: 0, weatherCode: 3, cloudCoverPct: 80, windKmh: 12)
        XCTAssertTrue(WeatherFill.apply(c, to: &r, manual: false))
        XCTAssertEqual(r.temperature, 30, "automatic keeps a typed value")
        XCTAssertEqual(r.sky, "sun")
        XCTAssertEqual(r.humidity, 55, "JavaScript Math.round: 54.5 goes up")
        XCTAssertEqual(r.wind, "light")
        XCTAssertTrue(WeatherFill.apply(c, to: &r, manual: true))
        XCTAssertEqual(r.temperature, 24); XCTAssertEqual(r.sky, "overcast")
        XCTAssertEqual(WeatherFill.summary(c, at: "09:41"), "Filled from your location at 09:41: Overcast, 24°C, 55% humidity, wind 12 km/h. Change any value you like.")
        XCTAssertFalse(WeatherFill.apply(WeatherSample(), to: &r, manual: true), "nothing to fill")
    }

    func testAutoFillPolicy() {
        let empty = Round(id: "r", createdAt: "", date: "2026-10-22", startTime: "09:00")
        XCTAssertTrue(WeatherFill.shouldAutoFill(round: empty, enabled: true, started: false, alreadyTried: false, networkAllowsAutomatic: true))
        XCTAssertFalse(WeatherFill.shouldAutoFill(round: empty, enabled: true, started: false, alreadyTried: false, networkAllowsAutomatic: false), "Low Data Mode")
        XCTAssertFalse(WeatherFill.shouldAutoFill(round: empty, enabled: true, started: true, alreadyTried: false, networkAllowsAutomatic: true), "round started")
        XCTAssertFalse(WeatherFill.shouldAutoFill(round: empty, enabled: false, started: false, alreadyTried: false, networkAllowsAutomatic: true))
        var typed = empty; typed.humidity = 40
        XCTAssertFalse(WeatherFill.shouldAutoFill(round: typed, enabled: true, started: false, alreadyTried: false, networkAllowsAutomatic: true))
    }

    func testURLAndParsing() throws {
        let url = try XCTUnwrap(OpenMeteoClient.url(latitude: 25.123456, longitude: 55.98761))
        XCTAssertEqual(url.absoluteString, "https://api.open-meteo.com/v1/forecast?latitude=25.1235&longitude=55.9876&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m&wind_speed_unit=kmh&timezone=auto")
        let json = #"{"current":{"temperature_2m":31.4,"relative_humidity_2m":48,"precipitation":0,"weather_code":1,"cloud_cover":12,"wind_speed_10m":9.7}}"#
        let s = try OpenMeteoClient.parse(Data(json.utf8))
        XCTAssertEqual(s, WeatherSample(temperatureC: 31.4, humidityPct: 48, precipitationMm: 0, weatherCode: 1, cloudCoverPct: 12, windKmh: 9.7))
        XCTAssertEqual(s.sky, .sun); XCTAssertEqual(s.wind, .light)
        XCTAssertThrowsError(try OpenMeteoClient.parse(Data("{}".utf8)))
        let session = OpenMeteoClient.makeSession()
        XCTAssertEqual(session.configuration.timeoutIntervalForRequest, 15)
        XCTAssertFalse(session.configuration.allowsConstrainedNetworkAccess)
        XCTAssertFalse(session.configuration.waitsForConnectivity)
        XCTAssertNil(session.configuration.urlCache)
    }
}
