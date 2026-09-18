import Foundation
import QuothCore

public final class FakeTranscriptionBackend: TranscriptionBackend, @unchecked Sendable {
    public let id = "fake"
    public let sendsAudioOffDevice = false
    private let lock = NSLock()
    private var result: Result<String, TranscriptionError>
    private var transcribed: [AudioClip] = []
    private var options: [TranscriptionOptions] = []
    private var prepared = 0

    public init(result: Result<String, TranscriptionError> = .success("Hello world.")) {
        self.result = result
    }

    public var transcribedClips: [AudioClip] {
        lock.withLock { transcribed }
    }

    public var receivedOptions: [TranscriptionOptions] {
        lock.withLock { options }
    }

    public var prepareCount: Int {
        lock.withLock { prepared }
    }

    public func setResult(_ result: Result<String, TranscriptionError>) {
        lock.withLock { self.result = result }
    }

    public func prepare(progress: (@Sendable (ModelLoadProgress) -> Void)?) async throws {
        lock.withLock { prepared += 1 }
        progress?(.ready)
    }

    public func transcribe(_ audio: AudioClip, options: TranscriptionOptions) async throws -> Transcript {
        try TranscriptionRules.validate(audio)
        let current = lock.withLock {
            transcribed.append(audio)
            self.options.append(options)
            return result
        }
        return try Transcript(text: current.get(), language: "en", audioDuration: audio.duration, backendID: id)
    }
}
