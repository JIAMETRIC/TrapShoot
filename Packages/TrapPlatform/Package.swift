// swift-tools-version: 5.9
import PackageDescription

// TrapPlatform: the mobile-platform concerns, kept out of the screens and out of the domain.
// App lifecycle, power and thermal state, network path, local notifications, storage reporting,
// recordings on disk, settings persistence, app identity. iOS only (UIKit, Network, UserNotifications).
let package = Package(
    name: "TrapPlatform",
    platforms: [.iOS(.v17)],
    products: [.library(name: "TrapPlatform", targets: ["TrapPlatform"])],
    targets: [
        .target(name: "TrapPlatform"),
        .testTarget(name: "TrapPlatformTests", dependencies: ["TrapPlatform"])
    ]
)
