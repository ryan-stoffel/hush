import AppKit
import XCTest
@testable import HushKit

@MainActor
final class OverlayTests: XCTestCase {
    func testPanelNeverTakesFocus() {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    }

    func testPanelIsCenteredAboveTheBottomEdge() {
        let origin = OverlayPanelController.origin(
            forPanelOf: CGSize(width: 200, height: 50),
            in: CGRect(x: 100, y: 80, width: 1000, height: 700)
        )
        XCTAssertEqual(origin, CGPoint(x: 500, y: 80 + OverlayPanelController.bottomMargin))
    }

    func testViewModelResetsBetweenDictations() {
        let model = OverlayViewModel()
        model.append(level: 0.8)
        model.elapsed = 12
        model.mode = .error("x")
        model.resetForNewDictation()
        XCTAssertEqual(model.mode, .listening)
        XCTAssertEqual(model.elapsedText, "0:00")
        XCTAssertEqual(model.waveform.levels.max(), 0)
    }

    func testShowAndHide() {
        let controller = OverlayPanelController()
        controller.showStatic(mode: .transcribing)
        XCTAssertTrue(controller.isVisible)
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }
}
