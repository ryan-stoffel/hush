import Foundation

public struct TranscriptionOptions: Equatable, Sendable {
    /// ISO 639-1 code such as "en". Nil means detect the language from the audio.
    public var language: String?
    /// Names and terms the backend should prefer when it has a way to take hints.
    public var vocabulary: [String]

    public init(language: String? = nil, vocabulary: [String] = []) {
        self.language = language
        self.vocabulary = vocabulary
    }

    public static let automatic = TranscriptionOptions()
}

public struct Transcript: Equatable, Sendable {
    public let text: String
    public let language: String?
    public let audioDuration: TimeInterval
    public let backendID: String

    public init(text: String, language: String?, audioDuration: TimeInterval, backendID: String) {
        self.text = text
        self.language = language
        self.audioDuration = audioDuration
        self.backendID = backendID
    }
}

public enum TranscriptionError: Error, Equatable {
    case tooShort
    case unsupportedHardware
    case modelUnavailable(String)
    case failed(String)
}

public enum ModelLoadProgress: Equatable, Sendable {
    case downloading(fraction: Double)
    case loading
    case ready
}

/// Every transcription engine, on-device or cloud, sits behind this protocol.
public protocol TranscriptionBackend: Sendable {
    var id: String { get }
    /// True when audio leaves the machine.
    var sendsAudioOffDevice: Bool { get }
    func prepare(progress: (@Sendable (ModelLoadProgress) -> Void)?) async throws
    func transcribe(_ audio: AudioClip, options: TranscriptionOptions) async throws -> Transcript
}

public enum TranscriptionRules {
    public static let minimumDuration: TimeInterval = 0.3

    public static func validate(_ audio: AudioClip) throws {
        guard audio.duration >= minimumDuration else { throw TranscriptionError.tooShort }
    }
}
