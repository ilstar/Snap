import XCTest
import CoreGraphics
@testable import SnapCore

final class LayoutTests: XCTestCase {
    func testHalvesOnOffsetDisplay() {
        let bounds = CGRect(x: -1920, y: 25, width: 1920, height: 1050)
        XCTAssertEqual(GridSelection().frame(in: bounds, gap: 0), CGRect(x: -1920, y: 25, width: 960, height: 1050))
        XCTAssertEqual(GridSelection(x: 3).frame(in: bounds, gap: 0), CGRect(x: -960, y: 25, width: 960, height: 1050))
    }

    func testCustomRegionAndSpacing() {
        let selection = GridSelection(columns: 12, rows: 8, x: 2, y: 1, width: 7, height: 5)
        XCTAssertEqual(selection.frame(in: CGRect(x: 100, y: -800, width: 1200, height: 800), gap: 8),
                       CGRect(x: 308, y: -692, width: 684, height: 484))
    }

    func testInvalidPersistedSelectionIsClamped() {
        let selection = GridSelection(columns: 0, rows: 999, x: -4, y: 20, width: 0, height: 50).normalized
        XCTAssertEqual(selection, GridSelection(columns: 2, rows: 12, x: 0, y: 11, width: 1, height: 1))
        let frame = selection.frame(in: CGRect(x: 0, y: 0, width: 100, height: 100), gap: 1000)
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
    }

    func testCoordinateConversionForDisplaysAboveAndBelowMain() {
        XCTAssertEqual(WindowGeometry.accessibilityFrame(from: CGRect(x: 0, y: 900, width: 1600, height: 1000), mainScreenTop: 900),
                       CGRect(x: 0, y: -1000, width: 1600, height: 1000))
        XCTAssertEqual(WindowGeometry.accessibilityFrame(from: CGRect(x: 0, y: -800, width: 1600, height: 800), mainScreenTop: 900),
                       CGRect(x: 0, y: 900, width: 1600, height: 800))
    }

    func testMovementClampsAtAllEdgesWithoutResizing() {
        let bounds = CGRect(x: -1000, y: 30, width: 1000, height: 800)
        let window = CGRect(x: -900, y: 100, width: 500, height: 400)
        XCTAssertEqual(WindowGeometry.moved(window, dx: -500, dy: -500, within: bounds), CGRect(x: -1000, y: 30, width: 500, height: 400))
        XCTAssertEqual(WindowGeometry.moved(window, dx: 2000, dy: 2000, within: bounds), CGRect(x: -500, y: 430, width: 500, height: 400))
        XCTAssertEqual(WindowGeometry.moved(window, dx: 24, dy: -24, within: bounds), CGRect(x: -876, y: 76, width: 500, height: 400))
    }

    func testOversizeWindowDoesNotProduceInvertedBounds() {
        let window = CGRect(x: 100, y: 100, width: 1800, height: 1200)
        XCTAssertEqual(WindowGeometry.moved(window, dx: 24, dy: 24, within: CGRect(x: 0, y: 25, width: 1440, height: 875)),
                       CGRect(x: 0, y: 25, width: 1800, height: 1200))
    }

    func testPresetsAndShortcutsRoundTrip() throws {
        let presets = Preset.defaults
        XCTAssertEqual(Set(presets.compactMap(\.shortcut)).count, presets.count)
        XCTAssertEqual(try JSONDecoder().decode([Preset].self, from: JSONEncoder().encode(presets)), presets)
        XCTAssertEqual(presets.filter { $0.action == .move }.count, 1)
        XCTAssertEqual(presets.filter { $0.action == .fullScreen }.count, 1)
        let fill = try XCTUnwrap(presets.first { $0.name == "Fill screen" })
        let screen = CGRect(x: 0, y: 25, width: 1440, height: 850)
        XCTAssertEqual(fill.selection.frame(in: screen, gap: 0), screen)
        XCTAssertEqual(fill.selection.frame(in: screen, gap: 8), screen)
    }
}
