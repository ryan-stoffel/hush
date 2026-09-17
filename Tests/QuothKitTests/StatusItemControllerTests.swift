import QuothCore
import XCTest
@testable import QuothKit

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testButtonFollowsTheState() {
        let state = AppState()
        let controller = StatusItemController(appState: state)
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }

        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Quoth, ready")
        XCTAssertEqual(controller.statusItem.button?.image?.isTemplate, true)

        state.transition(to: .listening)
        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Quoth, listening")
        XCTAssertEqual(controller.statusItem.button?.toolTip, "Listening")

        state.transition(to: .error("No microphone"))
        XCTAssertEqual(controller.statusItem.button?.accessibilityLabel(), "Quoth, error: No microphone")
    }

    func testButtonHasAStableAccessibilityIdentifier() {
        let controller = StatusItemController(appState: AppState())
        defer { NSStatusBar.system.removeStatusItem(controller.statusItem) }
        XCTAssertEqual(controller.statusItem.button?.accessibilityIdentifier(), "quoth.statusItem")
    }
}
