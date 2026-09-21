import XCTest
@testable import PokeTokenBar

final class PrivateSaveCompatibilityTests: XCTestCase {
    func testSnapshotPreservesEveryLegacyField() throws {
        guard let path = ProcessInfo.processInfo.environment["PTB_COMPAT_SNAPSHOT"] else {
            throw XCTSkip("Provide an external save snapshot; never commit user data")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoded = try JSONDecoder().decode(CompanionState.self, from: data)
        let encoded = try JSONEncoder().encode(decoded)
        let old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let new = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        func check(_ original: Any, _ updated: Any?, path: String) {
            if let dictionary = original as? [String: Any] {
                guard let next = updated as? [String: Any] else { XCTFail("Missing object at \(path)"); return }
                for (key, value) in dictionary { check(value, next[key], path: path + "." + key) }
            } else if let array = original as? [Any] {
                guard let next = updated as? [Any] else { XCTFail("Missing array at \(path)"); return }
                XCTAssertEqual(array.count, next.count, path)
                for (index, pair) in zip(array, next).enumerated() { check(pair.0, pair.1, path: path + "[\(index)]") }
            } else if original is NSNull {
                XCTAssertTrue(updated == nil || updated is NSNull, path)
            } else {
                XCTAssertEqual(original as? NSObject, updated as? NSObject, path)
            }
        }
        check(old, new, path: "save")
    }
}
