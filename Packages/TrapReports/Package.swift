// swift-tools-version: 5.9
import PackageDescription

// TrapReports: everything the shooter sends out of the app. One exporter protocol, a template-method export,
// a factory per screen, and the scorecard as a SwiftUI document rendered to PNG and vector PDF.
let package = Package(
    name: "TrapReports",
    platforms: [.iOS(.v17)],
    products: [.library(name: "TrapReports", targets: ["TrapReports"])],
    dependencies: [.package(path: "../TrapCore"), .package(path: "../TrapData"), .package(path: "../TrapDesign")],
    targets: [
        .target(name: "TrapReports", dependencies: [
            .product(name: "TrapCore", package: "TrapCore"),
            .product(name: "TrapData", package: "TrapData"),
            .product(name: "TrapDesign", package: "TrapDesign")
        ])
    ]
)
