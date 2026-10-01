import XCTest
import CoreGraphics
@testable import SnapCore

final class WindowRestoreTests: XCTestCase {
    func testSeveralLayoutsAndMovementKeepTheOriginalFrame() {
        var history = WindowRestoreHistory<String>()
        let original = CGRect(x: 180, y: 90, width: 750, height: 540)
        history.remember(original, for: "window")
        history.remember(CGRect(x: 0, y: 25, width: 1440, height: 875), for: "window")
        history.remember(CGRect(x: 720, y: 25, width: 720, height: 875), for: "window")
        XCTAssertEqual(history.originalFrame(for: "window"), original)
    }

    func testDifferentWindowsKeepIndependentFrames() {
        var history = WindowRestoreHistory<String>()
        let first = CGRect(x: -900, y: 25, width: 650, height: 450)
        let second = CGRect(x: 180, y: -800, width: 700, height: 400)
        history.remember(first, for: "first")
        history.remember(second, for: "second")
        history.forget("first")
        XCTAssertNil(history.originalFrame(for: "first"))
        XCTAssertEqual(history.originalFrame(for: "second"), second)
        XCTAssertNil(history.originalFrame(for: "untouched"))
    }

    func testNextChangeAfterRestoreStartsANewSnapshot() {
        var history = WindowRestoreHistory<Int>()
        history.remember(CGRect(x: 100, y: 80, width: 600, height: 400), for: 1)
        history.forget(1)
        let nextOriginal = CGRect(x: 250, y: 120, width: 900, height: 600)
        history.remember(nextOriginal, for: 1)
        XCTAssertEqual(history.originalFrame(for: 1), nextOriginal)
    }

    func testTerminatedApplicationHistoryCanBeDiscardedIndependently() {
        var history = WindowRestoreHistory<Int>()
        let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
        history.remember(frame, for: 1)
        history.remember(frame, for: 2)
        history.forget { $0 == 1 }
        XCTAssertNil(history.originalFrame(for: 1))
        XCTAssertEqual(history.originalFrame(for: 2), frame)
    }

    func testExistingSettingsGetRestoreWithoutChangingCustomizations() throws {
        var existing = Preset.defaults.filter { $0.action != .restore }
        existing[0].name = "My left side"
        existing[0].selection = GridSelection(columns: 8, width: 5)
        existing[0].shortcut = nil
        let migrated = Preset.addingRestoreIfMissing(to: existing)
        XCTAssertEqual(Array(migrated.dropLast()), existing)
        XCTAssertEqual(migrated.last?.action, .restore)
        XCTAssertEqual(migrated.last?.shortcut, Shortcut(keyCode: 15, modifiers: 4096 | 2048))
        XCTAssertEqual(Preset.addingRestoreIfMissing(to: migrated), migrated)
        XCTAssertEqual(try JSONDecoder().decode([Preset].self, from: JSONEncoder().encode(migrated)), migrated)
    }

    func testMigrationDoesNotTakeAnOccupiedShortcut() {
        let existing = [Preset(name: "Custom", shortcut: Preset.restoreDefault.shortcut)]
        let migrated = Preset.addingRestoreIfMissing(to: existing)
        XCTAssertEqual(migrated.first, existing.first)
        XCTAssertEqual(migrated.last?.action, .restore)
        XCTAssertNil(migrated.last?.shortcut)
    }

    func testMigrationPreservesAnAlreadyCustomizedRestoreAction() {
        var presets = Preset.defaults
        let index = presets.firstIndex { $0.action == .restore }!
        presets[index].name = "Go back"
        presets[index].shortcut = Shortcut(keyCode: 6, modifiers: 256 | 2048)
        XCTAssertEqual(Preset.addingRestoreIfMissing(to: presets), presets)
    }
}
