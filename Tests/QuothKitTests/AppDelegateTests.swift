import QuothCore
import XCTest
@testable import QuothKit

final class AppDelegateTests: XCTestCase {
    func testKeepsRunningWithoutWindows() {
        let delegate = AppDelegate(demoMode: .disabled)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    func testStoresDemoMode() {
        let mode = DemoMode(isEnabled: true, sceneName: "popover")
        XCTAssertEqual(AppDelegate(demoMode: mode).demoMode, mode)
    }
}
