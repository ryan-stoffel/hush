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

    func testPopover() {
        launch(scene: "popover")
        capture(app.popovers.firstMatch, named: "popover")
    }

    func testPopoverWithMissingPermissions() {
        launch(scene: "popover-permissions")
        capture(app.popovers.firstMatch, named: "popover-permissions")
    }

    func testOverlayListening() {
        launch(scene: "overlay-listening")
        capture(app.dialogs["overlay.panel"], named: "overlay-listening")
    }

    func testOverlayTranscribing() {
        launch(scene: "overlay-transcribing")
        capture(app.dialogs["overlay.panel"], named: "overlay-transcribing")
    }

    func testHistory() {
        launch(scene: "history")
        let window = app.windows["history.window"]
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        // Select the newest entry so the detail pane is captured too.
        let firstRow = window.outlines.firstMatch.cells.firstMatch
        if firstRow.waitForExistence(timeout: 5) {
            firstRow.click()
        }
        capture(window, named: "history")
    }
}
