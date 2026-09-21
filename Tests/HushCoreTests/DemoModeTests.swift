import XCTest
@testable import HushCore

final class DemoModeTests: XCTestCase {
    func testDisabledWithoutArguments() {
        XCTAssertEqual(DemoMode(arguments: ["/path/to/app"]), .disabled)
    }

    func testEnabledWithScene() {
        let mode = DemoMode(arguments: ["app", "-demoMode", "YES", "-demoScene", "popover"])
        XCTAssertTrue(mode.isEnabled)
        XCTAssertEqual(mode.sceneName, "popover")
    }

    func testSceneIsIgnoredWhenDemoModeIsOff() {
        let mode = DemoMode(arguments: ["app", "-demoScene", "popover"])
        XCTAssertFalse(mode.isEnabled)
        XCTAssertNil(mode.sceneName)
    }

    func testAcceptsCommonTruthyValues() {
        for value in ["YES", "yes", "true", "1"] {
            XCTAssertTrue(DemoMode(arguments: ["-demoMode", value]).isEnabled, value)
        }
        for value in ["NO", "false", "0", "maybe"] {
            XCTAssertFalse(DemoMode(arguments: ["-demoMode", value]).isEnabled, value)
        }
    }

    func testFlagWithoutValueIsIgnored() {
        XCTAssertFalse(DemoMode(arguments: ["-demoMode"]).isEnabled)
        XCTAssertNil(DemoMode(arguments: ["-demoMode", "YES", "-demoScene", "-other"]).sceneName)
    }

    func testDemoStateIsParsed() {
        XCTAssertEqual(DemoMode(arguments: ["-demoMode", "YES", "-demoState", "listening"]).state, .listening)
        XCTAssertEqual(DemoMode(arguments: ["-demoMode", "YES", "-demoState", "transcribing"]).state, .transcribing)
        XCTAssertEqual(
            DemoMode(arguments: ["-demoMode", "YES", "-demoState", "error"]).state,
            .error(DemoMode.demoErrorMessage)
        )
    }

    func testUnknownOrMissingDemoStateIsIdle() {
        XCTAssertEqual(DemoMode(arguments: ["-demoMode", "YES", "-demoState", "bogus"]).state, .idle)
        XCTAssertEqual(DemoMode(arguments: ["-demoMode", "YES"]).state, .idle)
        XCTAssertEqual(DemoMode(arguments: ["-demoState", "listening"]).state, .idle)
    }
}
