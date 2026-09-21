import AppKit
import Combine
import HushCore

@MainActor
public final class StatusItemController {
    public static let accessibilityIdentifier = "hush.statusItem"

    public let statusItem: NSStatusItem
    private let appState: AppState
    private var cancellables: Set<AnyCancellable> = []

    public init(appState: AppState, statusBar: NSStatusBar = .system) {
        self.appState = appState
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.setAccessibilityIdentifier(Self.accessibilityIdentifier)
        statusItem.button?.imagePosition = .imageOnly
        apply(StatusPresentation(state: appState.dictation))

        appState.$dictation
            .removeDuplicates()
            .sink { [weak self] state in
                self?.apply(StatusPresentation(state: state))
            }
            .store(in: &cancellables)
    }

    func apply(_ presentation: StatusPresentation) {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: presentation.accessibilityLabel
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = presentation.title
        button.setAccessibilityLabel(presentation.accessibilityLabel)
    }
}
