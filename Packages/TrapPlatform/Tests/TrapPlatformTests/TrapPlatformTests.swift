import XCTest
import SwiftUI
@testable import TrapPlatform

@MainActor
final class TrapPlatformTests: XCTestCase {
    final class Spy: LifecycleParticipant {
        var log: [String] = []
        func appWillResignActive() { log.append("resign") }
        func appDidEnterBackground() { log.append("background") }
        func appWillEnterForeground() { log.append("foreground") }
        func appDidBecomeActive() { log.append("active") }
    }

    func testLifecycleOrder() {
        let c = LifecycleCoordinator(), spy = Spy()
        c.add(spy)
        c.handle(.active)                      // launch
        c.handle(.inactive)                    // control centre
        c.handle(.active)
        c.handle(.inactive); c.handle(.background)   // home button
        c.handle(.inactive); c.handle(.active)       // back
        XCTAssertEqual(spy.log, ["active", "resign", "active", "resign", "background", "foreground", "active"])
        XCTAssertTrue(c.returnedFromBackground)
        XCTAssertNotNil(c.lastBackgroundedAt)
    }

    func testPowerAdvice() {
        XCTAssertEqual(PowerMonitor.advice(level: 0.8, state: .unplugged, lowPower: false, thermal: .nominal), .normal)
        XCTAssertTrue(PowerMonitor.advice(level: 0.15, state: .unplugged, lowPower: false, thermal: .nominal).isConserving)
        XCTAssertEqual(PowerMonitor.advice(level: 0.15, state: .charging, lowPower: false, thermal: .nominal), .normal)
        if case .critical = PowerMonitor.advice(level: 0.05, state: .unplugged, lowPower: false, thermal: .nominal) {} else { XCTFail("critical expected") }
        if case .critical = PowerMonitor.advice(level: 0.9, state: .charging, lowPower: false, thermal: .critical) {} else { XCTFail("critical expected") }
        XCTAssertTrue(PowerMonitor.advice(level: -1, state: .unknown, lowPower: true, thermal: .nominal).isConserving)
        XCTAssertEqual(PowerMonitor.advice(level: -1, state: .unknown, lowPower: false, thermal: .fair), .normal)
    }

    func testNotificationBody() {
        XCTAssertEqual(LocalNotifier.body(sessionId: "20261022-0930-MT", targetsLeft: 1), "20261022-0930-MT has 1 target left. Open TrapShoot to finish or close it.")
        XCTAssertEqual(LocalNotifier.body(sessionId: "", targetsLeft: 7), "Your round has 7 targets left. Open TrapShoot to finish or close it.")
    }

    func testCodableDefaults() {
        struct S: Codable, Equatable { var a = 1; var b = "x" }
        let d = UserDefaults(suiteName: "TrapPlatformTests")!
        d.removePersistentDomain(forName: "TrapPlatformTests")
        let store = CodableDefaults(key: "s", fallback: S(), defaults: d)
        XCTAssertEqual(store.load(), S())
        store.save(S(a: 5, b: "y"))
        XCTAssertEqual(store.load(), S(a: 5, b: "y"))
        store.reset()
        XCTAssertEqual(store.load(), S())
    }

    func testRecordingsStoreAndReport() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = RecordingsStore(folder: dir)
        XCTAssertEqual(store.list(), [])
        let a = dir.appendingPathComponent("shooterpro-a.m4a"), b = dir.appendingPathComponent("shooterpro-b.m4a")
        try Data(count: 1000).write(to: a); try Data(count: 500).write(to: b)
        try "{}".write(to: dir.appendingPathComponent("shooterpro-a.json"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -40 * 86_400)], ofItemAtPath: b.path)
        let list = store.list()
        XCTAssertEqual(list.map(\.name), ["shooterpro-a.m4a", "shooterpro-b.m4a"])
        XCTAssertNotNil(list[0].sidecar); XCTAssertNil(list[1].sidecar)
        XCTAssertEqual(store.totalBytes, 1500)
        XCTAssertEqual(store.deleteOlder(than: 30), 1)
        XCTAssertEqual(store.list().count, 1)
        try store.delete(store.list()[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("shooterpro-a.json").path))
        XCTAssertEqual(StorageReport.text(1_048_576), ByteCountFormatter.string(fromByteCount: 1_048_576, countStyle: .file))
    }
}
