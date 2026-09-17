import AppKit
import QuothCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let demoMode: DemoMode
    @MainActor public private(set) var appState: AppState?
    @MainActor private var statusItemController: StatusItemController?

    public init(demoMode: DemoMode = DemoMode(arguments: ProcessInfo.processInfo.arguments)) {
        self.demoMode = demoMode
        super.init()
    }

    @MainActor
    public func applicationDidFinishLaunching(_: Notification) {
        let appState = AppState(dictation: demoMode.isEnabled ? demoMode.state : .idle)
        self.appState = appState
        statusItemController = StatusItemController(appState: appState)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
