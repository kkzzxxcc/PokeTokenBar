import XCTest
@testable import PokeTokenBar

final class PrivateSaveCompatibilityTests: XCTestCase {
    func testPre257SaveDefaultsOnlyTheNewCosmeticFields() throws {
        let legacy = Data(#"{"usedSinceInstall":123456,"eggUsage":321,"inventory":{"rareCandy":7},"dex":[]}"#.utf8)
        let state = try JSONDecoder().decode(CompanionState.self, from: legacy)
        XCTAssertEqual(state.usedSinceInstall, 123456)
        XCTAssertEqual(state.eggUsage, 321)
        XCTAssertEqual(state.inventory["rareCandy"], 7)
        XCTAssertNil(state.eggPrayers)
        XCTAssertTrue(state.notifiedDexCompletions.isEmpty)
        XCTAssertFalse(state.dexCompletionsSeeded)
        let restored = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.usedSinceInstall, state.usedSinceInstall)
        XCTAssertEqual(restored.inventory, state.inventory)
    }

    func test257CosmeticFieldsSurviveSaveRoundTrip() throws {
        var state = CompanionState()
        state.eggPrayers = PrayerRecord(count: 3)
        state.notifiedDexCompletions = ["region-1"]
        state.dexCompletionsSeeded = true
        let restored = try JSONDecoder().decode(CompanionState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.eggPrayers, state.eggPrayers)
        XCTAssertEqual(restored.notifiedDexCompletions, state.notifiedDexCompletions)
        XCTAssertTrue(restored.dexCompletionsSeeded)
    }

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
                if path == "save.collectedFinals" {
                    XCTAssertEqual(Set(array.compactMap { $0 as? String }),
                                   Set(next.compactMap { $0 as? String }), path)
                    XCTAssertEqual(array.count, next.count, path)
                    return
                }
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
