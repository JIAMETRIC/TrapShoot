// swift-tools-version: 5.9
import PackageDescription

// TrapCore: the pure-Swift heart of TrapShooterPro. No UIKit, no AVFoundation, no storage.
// Round model, Olympic Trap rules, ISSF schemes, session ids, round document v2 codec,
// break-distance ballistics, CSV export and analysis. Every port is checked against the
// JavaScript original by the golden fixtures in Tests/TrapCoreTests/Fixtures.
let package = Package(
    name: "TrapCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TrapCore", targets: ["TrapCore"])],
    targets: [
        .target(name: "TrapCore"),
        .testTarget(name: "TrapCoreTests", dependencies: ["TrapCore"], resources: [.copy("Fixtures")])
    ]
)
