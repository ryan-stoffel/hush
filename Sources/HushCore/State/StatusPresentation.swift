import Foundation

/// What the menu bar item shows for a state. Symbol names are SF Symbols.
public struct StatusPresentation: Equatable, Sendable {
    public let symbolName: String
    public let accessibilityLabel: String
    public let title: String

    public init(state: DictationState, appName: String = AppInfo.name) {
        switch state {
        case .idle:
            symbolName = "mic"
            title = "Ready"
            accessibilityLabel = "\(appName), ready"
        case .listening:
            symbolName = "mic.fill"
            title = "Listening"
            accessibilityLabel = "\(appName), listening"
        case .transcribing:
            symbolName = "waveform"
            title = "Transcribing"
            accessibilityLabel = "\(appName), transcribing"
        case let .error(message):
            symbolName = "exclamationmark.triangle"
            title = message.isEmpty ? "Something went wrong" : message
            accessibilityLabel = "\(appName), error: \(title)"
        }
    }
}
