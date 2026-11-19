import CoreGraphics
import XCTest
@testable import SnapCore

final class DisplayMovementTests: XCTestCase {
    func testDestinationsFollowTheArrangementInAllFourDirections() {
        let source = display(x: 0, y: 0)
        let left = display(x: -1000, y: 200)
        let right = display(x: 1000, y: -200)
        let up = display(x: 200, y: -800)
        let down = display(x: -200, y: 800)
        let displays = [down, right, source, up, left]

        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .left, among: displays), left)
        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .right, among: displays), right)
        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .up, among: displays), up)
        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .down, among: displays), down)
        XCTAssertNil(WindowGeometry.destination(from: right, toward: .right, among: displays))
        XCTAssertNil(WindowGeometry.destination(from: source, toward: .up, among: [source]))
    }

    func testDestinationPrefersNearbyAlignedDisplayAndCanReachDiagonalDisplay() {
        let source = display(x: 0, y: 0)
        let nearest = display(x: 1100, y: 200)
        let farther = display(x: 2100, y: 0)
        let diagonal = display(x: 1000, y: -800)

        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .right, among: [farther, diagonal, nearest]), nearest)
        XCTAssertEqual(WindowGeometry.destination(from: source, toward: .right, among: [diagonal]), diagonal)
    }

    func testSourceIsTheDisplayWithLargestWindowOverlap() {
        let left = display(x: -1000, y: 200)
        let right = display(x: 0, y: 0)
        let window = CGRect(x: -200, y: 300, width: 300, height: 200)

        XCTAssertEqual(WindowGeometry.display(for: window, among: [right, left]), left)
    }

    func testTransferPreservesSizeAndRelativePosition() {
        let source = CGRect(x: 0, y: 20, width: 1000, height: 800)
        let destination = CGRect(x: -1200, y: -120, width: 1200, height: 900)
        let window = CGRect(x: 300, y: 320, width: 400, height: 200)

        XCTAssertEqual(WindowGeometry.transferred(window, from: source, to: destination),
                       CGRect(x: -800, y: 230, width: 400, height: 200))
    }

    func testTransferShrinksAnOversizedDimensionAndClampsTheOther() {
        let source = CGRect(x: 0, y: 20, width: 1000, height: 800)
        let destination = CGRect(x: 1000, y: 25, width: 600, height: 500)
        let window = CGRect(x: -50, y: 550, width: 900, height: 300)

        XCTAssertEqual(WindowGeometry.transferred(window, from: source, to: destination),
                       CGRect(x: 1000, y: 225, width: 600, height: 300))
    }

    func testExistingPresetsGetAllFourActionsWithoutTakingAnOccupiedShortcut() throws {
        let modifiers: UInt32 = 4096 | 2048 | 512
        let occupied = Shortcut(keyCode: 123, modifiers: modifiers)
        let existing = [Preset(name: "Custom", shortcut: occupied), Preset.restoreDefault]
        let migrated = Preset.addingMissingActions(to: existing)
        let added = Array(migrated.dropFirst(existing.count))

        XCTAssertEqual(Array(migrated.prefix(existing.count)), existing)
        XCTAssertEqual(added.map(\.action), [.moveScreenLeft, .moveScreenRight, .moveScreenUp, .moveScreenDown])
        XCTAssertEqual(added.map(\.shortcut), [nil, Shortcut(keyCode: 124, modifiers: modifiers),
                                                Shortcut(keyCode: 126, modifiers: modifiers),
                                                Shortcut(keyCode: 125, modifiers: modifiers)])
        XCTAssertEqual(Preset.addingMissingActions(to: migrated), migrated)
        XCTAssertEqual(try JSONDecoder().decode([Preset].self, from: JSONEncoder().encode(migrated)), migrated)
    }

    private func display(x: CGFloat, y: CGFloat) -> WindowDisplay {
        let frame = CGRect(x: x, y: y, width: 1000, height: 800)
        return WindowDisplay(frame: frame, visibleFrame: frame.insetBy(dx: 0, dy: 20))
    }
}
