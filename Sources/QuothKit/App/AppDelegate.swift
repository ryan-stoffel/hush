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
        let scene = demoMode.isEnabled ? demoMode.sceneName.flatMap(DemoScene.init(rawValue:)) : nil
        let permissions: any PermissionsProviding = demoMode.isEnabled
            ? DemoData.permissions(for: scene)
            : SystemPermissionsService()
        popoverController = PopoverController(
            statusItem: statusItemController.statusItem,
            model: PopoverViewModel(appState: appState, permissions: permissions)
        )
        if let scene {
            open(scene, appState: appState)
        }
    }

    @MainActor
    private func open(_ scene: DemoScene, appState: AppState) {
        switch scene {
        case .popover, .popoverPermissions:
            appState.lastDictation = DemoData.lastDictation
            popoverController?.showForDemo()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
