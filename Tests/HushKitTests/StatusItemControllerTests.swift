import HushCore
import XCTest
@testable import HushKit

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testButtonFollowsTheState() {
        let state = AppState()
        let controller = StatusItemController(appState: state)
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }

        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Hush, ready")
        XCTAssertEqual(controller.statusItem.button?.image?.isTemplate, true)

        state.transition(to: .listening)
        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Hush, listening")
        XCTAssertEqual(controller.statusItem.button?.toolTip, "Listening")

        state.transition(to: .error("No microphone"))
        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Hush, error: No microphone")
    }

    func testButtonHasAStableAccessibilityIdentifier() {
        let controller = StatusItemController(appState: AppState())
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }
        XCTAssertEqual(controller.statusItem.button?.accessibilityIdentifier(), "hush.statusItem")
    }
}
