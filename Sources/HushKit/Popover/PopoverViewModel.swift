import AppKit
import Combine
import HushCore

@MainActor
public final class PopoverViewModel: ObservableObject {
    @Published public private(set) var presentation: PopoverPresentation

    private let appState: AppState
    private let permissions: any PermissionsProviding
    private let copyText: (String) -> Void
    private let quitApp: () -> Void
    private let openHistory: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    public init(
        appState: AppState,
        permissions: any PermissionsProviding,
        version: String = AppInfo.version(),
        copyText: @escaping (String) -> Void = GeneralPasteboard.copy,
        quitApp: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
        openHistory: @escaping () -> Void = {}
    ) {
        self.appState = appState
        self.permissions = permissions
        self.copyText = copyText
        self.quitApp = quitApp
        self.openHistory = openHistory
        appState.permissions = permissions.snapshot()
        presentation = PopoverPresentation(
            state: appState.dictation,
            lastDictation: appState.lastDictation,
            version: version,
            permissions: appState.permissions
        )
        appState.$dictation.combineLatest(appState.$lastDictation, appState.$permissions)
            .map { PopoverPresentation(state: $0, lastDictation: $1, version: version, permissions: $2) }
            .removeDuplicates()
            .sink { [weak self] in self?.presentation = $0 }
            .store(in: &cancellables)
    }

    public func copyLastDictation() {
        guard let text = presentation.lastDictation else { return }
        copyText(text)
    }

    public func refreshPermissions() {
        appState.permissions = permissions.snapshot()
    }

    /// Asks the system first. A permission that was already denied cannot be prompted again,
    /// so the matching System Settings pane opens instead.
    public func grant(_ permission: Permission) async {
        let wasDenied = permissions.status(of: permission) == .denied
        let status = await permissions.request(permission)
        if status != .granted, wasDenied || permission != .microphone {
            permissions.openSettings(for: permission)
        }
        refreshPermissions()
    }

    public func showHistory() {
        openHistory()
    }

    public func quit() {
        quitApp()
    }
}

public enum GeneralPasteboard {
    public static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
