import HushCore
import XCTest
@testable import HushKit

final class AppDelegateTests: XCTestCase {
    func testKeepsRunningWithoutWindows() {
        let delegate = AppDelegate(demoMode: .disabled)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    func testStoresDemoMode() {
        let mode = DemoMode(isEnabled: true, sceneName: "popover")
        XCTAssertEqual(AppDelegate(demoMode: mode).demoMode, mode)
    }

    @MainActor
    func testDemoModeUsesAnInMemorySettingsStore() {
        let delegate = AppDelegate(demoMode: DemoMode(isEnabled: true, sceneName: nil))
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.settings?.set(SettingKeys.cleanupEnabled, to: false)
        XCTAssertNil(UserDefaults.standard.data(forKey: SettingKeys.cleanupEnabled.name))
    }
}
