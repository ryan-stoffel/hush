import Foundation

/// Launch configuration for screenshots and UI tests.
///
/// `-demoMode YES -demoScene <name>` makes the app open one scene with seeded data
/// and keeps it away from the microphone, event taps, Accessibility, the Keychain and the network.
public struct DemoMode: Equatable, Sendable {
    public let isEnabled: Bool
    public let sceneName: String?
    public let state: DictationState

    public static let disabled = DemoMode(isEnabled: false, sceneName: nil)
    public static let demoErrorMessage = "Microphone access is off"

    public init(isEnabled: Bool, sceneName: String?, state: DictationState = .idle) {
        self.isEnabled = isEnabled
        self.sceneName = sceneName
        self.state = state
    }

    public init(arguments: [String]) {
        let enabled = Self.value(after: "-demoMode", in: arguments).map(Self.isTruthy) ?? false
        isEnabled = enabled
        sceneName = enabled ? Self.value(after: "-demoScene", in: arguments) : nil
        state = enabled ? Self.state(named: Self.value(after: "-demoState", in: arguments)) : .idle
    }

    static func state(named name: String?) -> DictationState {
        switch name.flatMap(DictationState.Kind.init(rawValue:)) {
        case .listening: .listening
        case .transcribing: .transcribing
        case .error: .error(demoErrorMessage)
        case .idle, nil: .idle
        }
    }

    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        let value = arguments[index + 1]
        return value.hasPrefix("-") ? nil : value
    }

    static func isTruthy(_ value: String) -> Bool {
        ["yes", "true", "1"].contains(value.lowercased())
    }
}
