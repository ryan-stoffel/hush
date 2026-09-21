import Foundation

public enum InsertionStrategy: String, Codable, Sendable {
    case accessibility
    case clipboardPaste
}

public struct InsertionResult: Equatable, Sendable {
    public let strategy: InsertionStrategy
    public let restoredClipboard: Bool

    public init(strategy: InsertionStrategy, restoredClipboard: Bool) {
        self.strategy = strategy
        self.restoredClipboard = restoredClipboard
    }
}

public enum InsertionError: Error, Equatable {
    case accessibilityNotGranted
    case emptyText
    case failed(String)
}

public protocol TextInserting: Sendable {
    func insert(_ text: String) async throws -> InsertionResult
}

/// Decides how text reaches the frontmost app. Paste works in native apps, Electron apps, browsers
/// and terminals, so it is the answer for every app until Accessibility insertion lands in v0.2.
public struct InsertionStrategySelector: Sendable {
    public init() {}

    public func strategy(forBundleIdentifier _: String?) -> InsertionStrategy {
        .clipboardPaste
    }
}
