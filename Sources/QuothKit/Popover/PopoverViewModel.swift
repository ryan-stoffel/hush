import AppKit
import Combine
import QuothCore

@MainActor
public final class PopoverViewModel: ObservableObject {
    @Published public private(set) var presentation: PopoverPresentation

    private let copyText: (String) -> Void
    private let quitApp: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    public init(
        appState: AppState,
        version: String = AppInfo.version(),
        copyText: @escaping (String) -> Void = GeneralPasteboard.copy,
        quitApp: @escaping () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.copyText = copyText
        self.quitApp = quitApp
        presentation = PopoverPresentation(
            state: appState.dictation,
            lastDictation: appState.lastDictation,
            version: version
        )
        appState.$dictation.combineLatest(appState.$lastDictation)
            .map { PopoverPresentation(state: $0, lastDictation: $1, version: version) }
            .removeDuplicates()
            .sink { [weak self] in self?.presentation = $0 }
            .store(in: &cancellables)
    }

    public func copyLastDictation() {
        guard let text = presentation.lastDictation else { return }
        copyText(text)
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
