import XCTest
@testable import SnapCore

final class AppVersionTests: XCTestCase {
    func testParsesReleaseTags() {
        XCTAssertEqual(AppVersion("v0.1.0")?.components, [0, 1, 0])
        XCTAssertEqual(AppVersion("1.2")?.components, [1, 2])
        XCTAssertEqual(AppVersion("1.2.0-beta.1")?.components, [1, 2, 0])
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("v1..2"))
        XCTAssertNil(AppVersion("latest"))
    }

    func testComparesNumericallyAndPadsMissingComponents() {
        XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.1.1")!)
        XCTAssertLessThan(AppVersion("0.9.0")!, AppVersion("0.10.0")!)
        XCTAssertEqual(AppVersion("1.0")!, AppVersion("1.0.0")!)
        XCTAssertFalse(AppVersion("1.0.0")! < AppVersion("v1.0")!)
    }
}
