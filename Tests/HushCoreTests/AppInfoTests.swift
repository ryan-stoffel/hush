import XCTest
@testable import HushCore

final class AppInfoTests: XCTestCase {
    func testNameIsStable() {
        XCTAssertEqual(AppInfo.name, "Hush")
    }

    func testVersionFallsBackOutsideAnAppBundle() {
        XCTAssertEqual(AppInfo.version(in: Bundle(for: Self.self)).isEmpty, false)
    }
}
