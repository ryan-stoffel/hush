import Foundation

/// What a model-backed cleaner receives. Never audio, never the destination app's content,
/// never anything read from the screen.
public struct LLMCleanupRequest: Equatable, Sendable {
    public var text: String
    public var language: String?
    public var toneInstruction: String?
    public var dictionaryTerms: [String]
    public var editLevel: EditLevel

    public init(
        text: String,
        language: String? = nil,
        toneInstruction: String? = nil,
        dictionaryTerms: [String] = [],
        editLevel: EditLevel = .light
    ) {
        self.text = text
        self.language = language
        self.toneInstruction = toneInstruction
        self.dictionaryTerms = dictionaryTerms
        self.editLevel = editLevel
    }
}

public enum EditLevel: String, Codable, CaseIterable, Sendable {
    /// Punctuation, casing, and obvious mis-hearings only.
    case light
    /// Also drops false starts and tightens wording.
    case medium
}

public enum LLMAvailability: Equatable, Sendable {
    case available
    case unavailable(String)

    public var isAvailable: Bool {
        self == .available
    }
}

public enum LLMError: Error, Equatable {
    case unavailable(String)
    case refused(String)
    case failed(String)
}

public protocol LLMCleaner: Sendable {
    var id: String { get }
    var displayName: String { get }
    /// True when text never leaves the machine.
    var isLocal: Bool { get }
    func availability() async -> LLMAvailability
    func clean(_ request: LLMCleanupRequest) async throws -> String
}
