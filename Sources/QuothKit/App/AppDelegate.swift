import AppKit
import QuothCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let demoMode: DemoMode
    @MainActor public private(set) var appState: AppState?
    @MainActor public private(set) var settings: SettingsStore?
    @MainActor public private(set) var history: HistoryStore?
    @MainActor private var statusItemController: StatusItemController?
    @MainActor private var popoverController: PopoverController?
    @MainActor private var overlayController: OverlayPanelController?
    @MainActor private var coordinator: DictationCoordinator?
    @MainActor private var historyWindow: HistoryWindowController?

    public init(demoMode: DemoMode = DemoMode(arguments: ProcessInfo.processInfo.arguments)) {
        self.demoMode = demoMode
        super.init()
    }

    @MainActor
    public func applicationDidFinishLaunching(_: Notification) {
        // Demo mode never touches UserDefaults.
        settings = demoMode.isEnabled
            ? SettingsStore.inMemory()
            : SettingsStore(storage: UserDefaultsKeyValueStore())
        history = settings.map { settings in
            demoMode.isEnabled
                ? HistoryStore(persistence: InMemoryHistoryPersistence(DemoData.historyEntries), settings: settings)
                : HistoryStore.onDisk(settings: settings)
        }
        let appState = AppState(dictation: demoMode.isEnabled ? demoMode.state : .idle)
        self.appState = appState
        let statusItemController = StatusItemController(appState: appState)
        self.statusItemController = statusItemController
        let scene = demoMode.isEnabled ? demoMode.sceneName.flatMap(DemoScene.init(rawValue:)) : nil
        let permissions: any PermissionsProviding = demoMode.isEnabled
            ? DemoData.permissions(for: scene)
            : SystemPermissionsService()
        if let settings, let history {
            historyWindow = HistoryWindowController(model: HistoryViewModel(store: history, settings: settings))
        }
        popoverController = PopoverController(
            statusItem: statusItemController.statusItem,
            model: PopoverViewModel(appState: appState, permissions: permissions) { [weak self] in
                self?.popoverController?.close()
                self?.historyWindow?.show()
            }
        )
        let overlayController = OverlayPanelController()
        self.overlayController = overlayController
        if let scene {
            open(scene, appState: appState)
        }
        // Demo mode stays away from the microphone, event taps, Accessibility and the network.
        guard !demoMode.isEnabled, let settings else { return }
        coordinator = makeCoordinator(
            appState: appState,
            permissions: permissions,
            overlay: overlayController,
            settings: settings
        )
        coordinator?.start()
    }

    @MainActor
    private func makeCoordinator(
        appState: AppState,
        permissions: any PermissionsProviding,
        overlay: OverlayPanelController,
        settings: SettingsStore
    ) -> DictationCoordinator {
        let foundationModels = FoundationModelsCleaner()
        let llmCleaner = FirstAvailableCleaner([foundationModels] + Self.localServerCleaner(from: settings))
        if settings.get(SettingKeys.stageEnabled(LLMCleanupStep.stageID)) {
            Task { await foundationModels.prewarm() }
        }
        return DictationCoordinator(
            appState: appState,
            hotkey: EventTapHotkeyMonitor(),
            capture: AudioCaptureService(),
            backend: WhisperKitBackend(),
            inserter: PasteInserter(),
            permissions: permissions,
            overlay: overlay,
            cleanup: CleanupPipeline(
                stages: CleanupStages.standard,
                asyncStep: LLMCleanupStep(cleaner: llmCleaner) { settings.get(SettingKeys.cleanupEditLevel) },
                settings: settings
            ),
            history: history,
            frontmostApp: {
                NSWorkspace.shared.frontmostApplication.map {
                    FrontmostApp(bundleIdentifier: $0.bundleIdentifier, name: $0.localizedName)
                }
            }
        )
    }

    static func localServerCleaner(from settings: SettingsStore) -> [any LLMCleaner] {
        let baseURL = settings.get(SettingKeys.localServerBaseURL)
        guard settings.get(SettingKeys.localServerEnabled),
              case let .success(url) = LoopbackURLValidator.validate(baseURL) else {
            return []
        }
        return [LocalServerCleaner(baseURL: url, model: settings.get(SettingKeys.localServerModel))]
    }

    @MainActor
    public func applicationWillTerminate(_: Notification) {
        coordinator?.stop()
    }

    @MainActor
    private func open(_ scene: DemoScene, appState: AppState) {
        switch scene {
        case .popover, .popoverPermissions:
            appState.lastDictation = DemoData.lastDictation
            popoverController?.showForDemo()
        case .overlayListening:
            overlayController?.model.setWaveform(DemoData.waveform)
            overlayController?.model.elapsed = DemoData.elapsed
            overlayController?.showStatic(mode: .listening)
        case .overlayTranscribing:
            overlayController?.showStatic(mode: .transcribing)
        case .history:
            historyWindow?.show(selecting: DemoData.historyEntries.first?.id)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
