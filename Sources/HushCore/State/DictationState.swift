import Foundation

public enum DictationState: Equatable, Sendable {
    case idle
    case listening
    case transcribing
    case error(String)

    public enum Kind: String, CaseIterable, Sendable {
        case idle
        case listening
        case transcribing
        case error
    }

    public var kind: Kind {
        switch self {
        case .idle: .idle
        case .listening: .listening
        case .transcribing: .transcribing
        case .error: .error
        }
    }

    public var isBusy: Bool {
        self == .listening || self == .transcribing
    }

    /// The pipeline only moves forward (idle, listening, transcribing, idle). Any state may fail,
    /// and an error is cleared by returning to idle or by starting a new dictation.
    public func canTransition(to next: DictationState) -> Bool {
        switch (kind, next.kind) {
        case (_, .error): true
        case (.idle, .listening): true
        case (.listening, .transcribing), (.listening, .idle): true
        case (.transcribing, .idle): true
        case (.error, .idle), (.error, .listening): true
        default: false
        }
    }
}
