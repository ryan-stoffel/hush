import XCTest
@testable import QuothCore

final class AppInfoTests: XCTestCase {
    func testNameIsStable() {
        XCTAssertEqual(AppInfo.name, "Quoth")
    }

    func testVersionFallsBackOutsideAnAppBundle() {
        XCTAssertEqual(AppInfo.version(in: Bundle(for: Self.self)).isEmpty, false)
    }
}
