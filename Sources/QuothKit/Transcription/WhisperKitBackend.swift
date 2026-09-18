import Foundation
import QuothCore
#if arch(arm64)
import WhisperKit
#endif

/// On-device transcription. The only network request it ever makes is the one-time model download.
public actor WhisperKitBackend: TranscriptionBackend {
    public static let defaultModel = "openai_whisper-large-v3-v20240930_turbo"

    public nonisolated let id = "whisperkit"
    public nonisolated let sendsAudioOffDevice = false

    private let model: String
    private let modelsDirectory: URL
    #if arch(arm64)
    private var pipeline: WhisperKit?
    #endif

    public init(model: String = WhisperKitBackend.defaultModel, modelsDirectory: URL? = nil) {
        self.model = model
        self.modelsDirectory = modelsDirectory ?? Self.defaultModelsDirectory()
    }

    public static func defaultModelsDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(AppInfo.name, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    public func prepare(progress: (@Sendable (ModelLoadProgress) -> Void)?) async throws {
        #if arch(arm64)
        guard pipeline == nil else {
            progress?(.ready)
            return
        }
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            let folder = try await WhisperKit.download(variant: model, downloadBase: modelsDirectory) { status in
                progress?(.downloading(fraction: status.fractionCompleted))
            }
            progress?(.loading)
            let config = WhisperKitConfig(
                model: model,
                modelFolder: folder.path,
                verbose: false,
                logLevel: .error,
                load: true,
                download: false
            )
            pipeline = try await WhisperKit(config)
            progress?(.ready)
        } catch {
            throw TranscriptionError.modelUnavailable(error.localizedDescription)
        }
        #else
        // WhisperKit does not support Intel Macs. A cloud backend is the only option there.
        throw TranscriptionError.unsupportedHardware
        #endif
    }

    public func transcribe(_ audio: AudioClip, options: TranscriptionOptions) async throws -> Transcript {
        try TranscriptionRules.validate(audio)
        #if arch(arm64)
        try await prepare(progress: nil)
        guard let pipeline else { throw TranscriptionError.modelUnavailable("The model is not loaded.") }

        var decoding = DecodingOptions()
        decoding.language = options.language
        decoding.detectLanguage = options.language == nil
        decoding.withoutTimestamps = true
        if let prompt = VocabularyPrompt.text(for: options.vocabulary), let tokenizer = pipeline.tokenizer {
            let tokens = tokenizer.encode(text: " " + prompt).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            decoding.promptTokens = VocabularyPrompt.trim(tokens)
            decoding.usePrefillPrompt = true
        }
        do {
            let results = try await pipeline.transcribe(audioArray: audio.samples, decodeOptions: decoding)
            let text = TranscriptSanitizer.clean(results.map(\.text).joined(separator: " "))
            return Transcript(
                text: text,
                language: results.first?.language,
                audioDuration: audio.duration,
                backendID: id
            )
        } catch {
            throw TranscriptionError.failed(error.localizedDescription)
        }
        #else
        throw TranscriptionError.unsupportedHardware
        #endif
    }
}
