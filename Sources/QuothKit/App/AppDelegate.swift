import AppKit
import QuothCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let demoMode: DemoMode
    @MainActor public private(set) var appState: AppState?
    @MainActor private var statusItemController: StatusItemController?
    @MainActor private var popoverController: PopoverController?

    public init(demoMode: DemoMode = DemoMode(arguments: ProcessInfo.processInfo.arguments)) {
        self.demoMode = demoMode
        super.init()
    }

    @MainActor
    public func applicationDidFinishLaunching(_: Notification) {
        let appState = AppState(dictation: demoMode.isEnabled ? demoMode.state : .idle)
        self.appState = appState
        let statusItemController = StatusItemController(appState: appState)
        self.statusItemController = statusItemController
        popoverController = PopoverController(
            statusItem: statusItemController.statusItem,
            model: PopoverViewModel(appState: appState)
        )
        if demoMode.isEnabled, let scene = demoMode.sceneName.flatMap(DemoScene.init(rawValue:)) {
            open(scene, appState: appState)
        }
    }

    @MainActor
    private func open(_ scene: DemoScene, appState: AppState) {
        switch scene {
        case .popover:
            appState.lastDictation = DemoData.lastDictation
            popoverController?.showForDemo()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
