import XCTest

final class ScreenshotTests: ScreenshotTestCase {
    func testLaunchesInDemoModeWithoutWindows() {
        launch(scene: nil)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15) || app.state == .runningForeground)
        XCTAssertEqual(app.windows.count, 0)
    }

    func testStatusItemStates() {
        for state in ["idle", "listening", "transcribing", "error"] {
            launch(scene: nil, extraArguments: ["-demoState", state])
            capture(app.statusItems["quoth.statusItem"], named: "status-item-\(state)")
            app.terminate()
        }
    }
}
