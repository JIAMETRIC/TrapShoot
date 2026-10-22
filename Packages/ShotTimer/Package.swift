// swift-tools-version: 5.9
import PackageDescription

// ShotTimer: the microphone shot timer. AudioDetector.swift and RoundRecorder.swift are the validated
// 7.0.7 sources, unchanged. TimerSession is the native replacement for MicBridge: same behaviour,
// observable state and typed events instead of JavaScript calls.
let package = Package(
    name: "ShotTimer",
    platforms: [.iOS(.v17)],
    products: [.library(name: "ShotTimer", targets: ["ShotTimer"])],
    targets: [.target(name: "ShotTimer")]
)
