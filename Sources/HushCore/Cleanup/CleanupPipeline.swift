import Foundation

public struct CleanupContext: Equatable, Sendable {
    public var language: String?
    public var bundleIdentifier: String?
    public var dictionary: [String]

    public init(language: String? = nil, bundleIdentifier: String? = nil, dictionary: [String] = []) {
        self.language = language
        self.bundleIdentifier = bundleIdentifier
        self.dictionary = dictionary
    }
}

/// One synchronous, rule-based step. Stages must be deterministic and must never touch the network.
public protocol CleanupStage: Sendable {
    var id: String { get }
    var displayName: String { get }
    /// False for stages that keep working when the global Cleanup toggle is off.
    var followsGlobalToggle: Bool { get }
    func process(_ text: String, context: CleanupContext) throws -> String
}

public extension CleanupStage {
    var followsGlobalToggle: Bool {
        true
    }

    var enabledKey: SettingKey<Bool> {
        SettingKeys.stageEnabled(id)
    }
}

/// The optional model-backed step that runs after the rules. Local and cloud cleaners conform.
public protocol AsyncCleanupStep: Sendable {
    var id: String { get }
    func process(_ text: String, context: CleanupContext) async throws -> String
}

public struct CleanupTraceEntry: Equatable, Sendable {
    public let stageID: String
    public let output: String
    public let errorDescription: String?
}

public struct CleanupResult: Equatable, Sendable {
    public let rawText: String
    public let finalText: String
    public let trace: [CleanupTraceEntry]

    public init(rawText: String, finalText: String, trace: [CleanupTraceEntry] = []) {
        self.rawText = rawText
        self.finalText = finalText
        self.trace = trace
    }
}

public protocol TextCleaning: AnyObject {
    func run(_ rawText: String, context: CleanupContext) async -> CleanupResult
}

/// Runs the enabled stages in the order they were given, then the optional async step.
///
/// Fallback rules: a stage that throws is skipped and the previous text carries on; an async step
/// that throws or exceeds the timeout leaves the rule-based result in place; and if the final text
/// is empty the raw transcript is returned, so a bug in a stage never makes a dictation vanish.
/// The trace holds dictated text. It stays in memory and is never logged.
public final class CleanupPipeline: TextCleaning {
    private let stages: [any CleanupStage]
    private let asyncStep: (any AsyncCleanupStep)?
    private let settings: SettingsStore
    private let asyncTimeout: TimeInterval

    public init(
        stages: [any CleanupStage],
        asyncStep: (any AsyncCleanupStep)? = nil,
        settings: SettingsStore,
        asyncTimeout: TimeInterval = 5
    ) {
        self.stages = stages
        self.asyncStep = asyncStep
        self.settings = settings
        self.asyncTimeout = asyncTimeout
    }

    public var stageIDs: [String] {
        stages.map(\.id)
    }

    public func run(_ rawText: String, context: CleanupContext) async -> CleanupResult {
        let globallyEnabled = settings.get(SettingKeys.cleanupEnabled)
        var text = rawText
        var trace: [CleanupTraceEntry] = []

        for stage in stages {
            guard settings.get(stage.enabledKey), globallyEnabled || !stage.followsGlobalToggle else { continue }
            do {
                text = try stage.process(text, context: context)
                trace.append(CleanupTraceEntry(stageID: stage.id, output: text, errorDescription: nil))
            } catch {
                trace.append(CleanupTraceEntry(stageID: stage.id, output: text, errorDescription: "\(error)"))
            }
        }

        if globallyEnabled, let asyncStep, settings.get(SettingKeys.stageEnabled(asyncStep.id)) {
            do {
                text = try await Self.withTimeout(asyncTimeout) { [text] in
                    try await asyncStep.process(text, context: context)
                }
                trace.append(CleanupTraceEntry(stageID: asyncStep.id, output: text, errorDescription: nil))
            } catch {
                trace.append(CleanupTraceEntry(stageID: asyncStep.id, output: text, errorDescription: "\(error)"))
            }
        }

        let isBlank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return CleanupResult(rawText: rawText, finalText: isBlank ? rawText : text, trace: trace)
    }

    struct TimeoutError: Error {}

    static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw TimeoutError() }
            return first
        }
    }
}
