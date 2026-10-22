// swift-tools-version: 5.9
import PackageDescription

// TrapWeather: the app's only network feature. One-shot location, one small Open-Meteo request,
// and the same sky/wind mapping as the 7.x page. Built to fail quietly on the range.
let package = Package(
    name: "TrapWeather",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TrapWeather", targets: ["TrapWeather"])],
    dependencies: [.package(path: "../TrapCore")],
    targets: [
        .target(name: "TrapWeather", dependencies: [.product(name: "TrapCore", package: "TrapCore")]),
        .testTarget(name: "TrapWeatherTests", dependencies: ["TrapWeather"])
    ]
)
