// swift-tools-version: 5.9
import PackageDescription

// TrapApp: the native app — screens, view models and the timing flow. The app target holds only the `@main` entry and
// links this package, so the UI builds and tests like every other package (ADR-017). Views stay thin; logic lives in
// TrapCore and the `@Observable` models here.
let package = Package(
    name: "TrapApp",
    platforms: [.iOS(.v17)],
    products: [.library(name: "TrapApp", targets: ["TrapApp"])],
    dependencies: [
        .package(path: "../TrapCore"), .package(path: "../TrapData"), .package(path: "../TrapDesign"),
        .package(path: "../ShotTimer"), .package(path: "../TrapReports"), .package(path: "../TrapWeather"),
        .package(path: "../TrapPlatform")
    ],
    targets: [
        .target(name: "TrapApp", dependencies: [
            .product(name: "TrapCore", package: "TrapCore"),
            .product(name: "TrapData", package: "TrapData"),
            .product(name: "TrapDesign", package: "TrapDesign"),
            .product(name: "ShotTimer", package: "ShotTimer"),
            .product(name: "TrapReports", package: "TrapReports"),
            .product(name: "TrapWeather", package: "TrapWeather"),
            .product(name: "TrapPlatform", package: "TrapPlatform")
        ]),
        .testTarget(name: "TrapAppTests", dependencies: [
            "TrapApp",
            .product(name: "TrapCore", package: "TrapCore"),
            .product(name: "TrapData", package: "TrapData"),
            .product(name: "ShotTimer", package: "ShotTimer")
        ])
    ]
)
