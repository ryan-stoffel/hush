import Foundation

/// Launch configuration for screenshots and UI tests.
///
/// `-demoMode YES -demoScene <name>` makes the app open one scene with seeded data
/// and keeps it away from the microphone, event taps, Accessibility, the Keychain and the network.
public struct DemoMode: Equatable, Sendable {
    public let isEnabled: Bool
    public let sceneName: String?

    public static let disabled = DemoMode(isEnabled: false, sceneName: nil)

    public init(isEnabled: Bool, sceneName: String?) {
        self.isEnabled = isEnabled
        self.sceneName = sceneName
    }

    public init(arguments: [String]) {
        let enabled = Self.value(after: "-demoMode", in: arguments).map(Self.isTruthy) ?? false
        isEnabled = enabled
        sceneName = enabled ? Self.value(after: "-demoScene", in: arguments) : nil
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
