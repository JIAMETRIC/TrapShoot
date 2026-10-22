// swift-tools-version: 5.9
import PackageDescription

// TrapData: local-first storage. A RoundRepository protocol, an in-memory implementation for tests and
// previews, a SwiftData implementation for the app, and the backup/import codecs.
let package = Package(
    name: "TrapData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TrapData", targets: ["TrapData"])],
    dependencies: [.package(path: "../TrapCore")],
    targets: [
        .target(name: "TrapData", dependencies: [.product(name: "TrapCore", package: "TrapCore")]),
        .testTarget(name: "TrapDataTests", dependencies: ["TrapData", .product(name: "TrapCore", package: "TrapCore")])
    ]
)
