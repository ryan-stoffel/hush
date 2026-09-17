import XCTest

final class ScreenshotTests: ScreenshotTestCase {
    func testLaunchesInDemoModeWithoutWindows() {
        launch(scene: nil)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15) || app.state == .runningForeground)
        XCTAssertEqual(app.windows.count, 0)
    }
}
