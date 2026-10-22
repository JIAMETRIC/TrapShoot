import Foundation
import XCTest
@testable import TrapCore

/// Loads the golden fixtures written by Tools/golden/generate.js from the 7.0.7 JavaScript.
enum Fixtures {
    static func json(_ name: String) throws -> Any {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw NSError(domain: "Fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(name).json"])
        }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    }
    static func dict(_ name: String) throws -> [String: Any] { try XCTUnwrap(json(name) as? [String: Any]) }
    static func array(_ name: String) throws -> [[String: Any]] { try XCTUnwrap(json(name) as? [[String: Any]]) }
}

/// Reads a JavaScript round object (same keys as the document, plus id) into a Round.
func fixtureRound(_ r: [String: Any]) -> Round {
    RoundDocument.round(id: r["id"] as? String ?? "", from: r)
}

func num(_ v: Any?) -> Double? { RoundDocument.jsonNumber(v) }
func int(_ v: Any?) -> Int? { num(v).map { Int($0) } }
func optDouble(_ v: Any?) -> Double? { v is NSNull ? nil : num(v) }

/// Compares our document with the JavaScript one key by key, with a useful message per key.
func assertDocument(_ ours: [String: Any], matches theirs: [String: Any], ignoring: Set<String> = ["updatedAt"], file: StaticString = #filePath, line: UInt = #line) {
    for (k, v) in ours where !ignoring.contains(k) {
        guard let t = theirs[k] else { XCTFail("key \(k) missing in fixture", file: file, line: line); continue }
        let a = v as AnyObject, b = t as AnyObject
        XCTAssertTrue(a.isEqual(b), "key \(k): ours \(v) theirs \(t)", file: file, line: line)
    }
}
