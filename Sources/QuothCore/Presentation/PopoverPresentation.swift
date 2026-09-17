import Foundation

/// Text shown in the menu bar popover, derived from the dictation state and the last dictation.
public struct PopoverPresentation: Equatable, Sendable {
    public static let emptyHint = "Hold Fn and speak. Release to insert the text at your cursor."

    public let statusText: String
    public let isError: Bool
    public let lastDictation: String?
    public let versionText: String

    public init(state: DictationState, lastDictation: String?, version: String) {
        statusText = StatusPresentation(state: state).title
        isError = state.kind == .error
        let trimmed = lastDictation?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastDictation = (trimmed?.isEmpty ?? true) ? nil : trimmed
        versionText = "Version \(version)"
    }

    public var showsEmptyHint: Bool {
        lastDictation == nil
    }
}
