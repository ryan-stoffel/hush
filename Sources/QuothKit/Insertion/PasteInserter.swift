import Foundation
import QuothCore

/// Inserts text by placing it on the clipboard, sending Cmd+V, and putting the previous clipboard back.
public final class PasteInserter: TextInserting, @unchecked Sendable {
    private let pasteboard: PasteboardAccessing
    private let keystroke: PasteKeystrokePosting
    private let settleDelay: TimeInterval
    private let restoreDelay: TimeInterval
    private let sleep: @Sendable (TimeInterval) async -> Void

    public init(
        pasteboard: PasteboardAccessing = GeneralPasteboardAccess(),
        keystroke: PasteKeystrokePosting = SystemPasteKeystroke(),
        settleDelay: TimeInterval = 0.05,
        restoreDelay: TimeInterval = 0.3,
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.pasteboard = pasteboard
        self.keystroke = keystroke
        self.settleDelay = settleDelay
        self.restoreDelay = restoreDelay
        self.sleep = sleep
    }

    @MainActor
    public func insert(_ text: String) async throws -> InsertionResult {
        guard !text.isEmpty else { throw InsertionError.emptyText }
        guard keystroke.isTrusted else { throw InsertionError.accessibilityNotGranted }

        let saved = pasteboard.snapshot()
        let ownChangeCount = pasteboard.write(text: text, markerTypes: PasteboardMarkers.all)
        await sleep(settleDelay)
        keystroke.postPaste()
        // The target app reads the clipboard asynchronously. Restoring too early pastes the old content.
        await sleep(restoreDelay)

        // If anything else wrote to the clipboard in the meantime, that content wins.
        guard pasteboard.changeCount == ownChangeCount else {
            return InsertionResult(strategy: .clipboardPaste, restoredClipboard: false)
        }
        pasteboard.restore(saved)
        return InsertionResult(strategy: .clipboardPaste, restoredClipboard: true)
    }
}
