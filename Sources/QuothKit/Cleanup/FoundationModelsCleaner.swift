import Foundation
import QuothCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Seam around the system model so the cleaner can be tested without Apple Intelligence.
public protocol LanguageModelResponding: Sendable {
    func availability() -> LLMAvailability
    func prewarm(instructions: String, examples: [PromptExample]) async
    func respond(instructions: String, examples: [PromptExample], prompt: String) async throws -> String
}

/// On-device cleanup through Apple's Foundation Models framework. Nothing leaves the machine.
/// A fresh session is used for every dictation so no text carries over between them.
public final class FoundationModelsCleaner: LLMCleaner {
    public let id = "foundation-models"
    public let displayName = "Apple Intelligence (on device)"
    public let isLocal = true

    /// How long the cleaner stays out of the way after the system model failed to load its assets.
    public static let cooldown: TimeInterval = 60

    private let model: any LanguageModelResponding
    private let now: () -> Date
    private let lock = NSLock()
    private var unavailableUntil: Date?
    private var lastFailure: String?

    public init(model: (any LanguageModelResponding)? = nil, now: @escaping () -> Date = Date.init) {
        self.model = model ?? SystemLanguageModelResponder()
        self.now = now
    }

    public func availability() async -> LLMAvailability {
        let cooled = lock.withLock { () -> String? in
            guard let until = unavailableUntil, now() < until else { return nil }
            return lastFailure
        }
        if let cooled {
            return .unavailable(cooled)
        }
        return model.availability()
    }

    /// Loads the model ahead of the first dictation so the first cleanup is not slow.
    public func prewarm() async {
        guard model.availability().isAvailable else { return }
        let request = LLMCleanupRequest(text: "")
        await model.prewarm(
            instructions: PromptBuilder.instructions(for: request),
            examples: PromptBuilder.examples(for: request.editLevel)
        )
    }

    public func clean(_ request: LLMCleanupRequest) async throws -> String {
        if case let .unavailable(reason) = await availability() {
            throw LLMError.unavailable(reason)
        }
        do {
            return try await model.respond(
                instructions: PromptBuilder.instructions(for: request),
                examples: PromptBuilder.examples(for: request.editLevel),
                prompt: PromptBuilder.message(for: request)
            )
        } catch let LLMError.unavailable(reason) {
            // The system says the model is available but its assets are not: back off instead of
            // delaying every dictation by a request that will fail.
            lock.withLock {
                unavailableUntil = now().addingTimeInterval(Self.cooldown)
                lastFailure = reason
            }
            throw LLMError.unavailable(reason)
        }
    }
}

public struct SystemLanguageModelResponder: LanguageModelResponding {
    public init() {}

    public func availability() -> LLMAvailability {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return .unavailable(Self.needsNewerMacOS) }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case let .unavailable(reason):
            return .unavailable(Self.message(for: reason))
        }
        #else
        return .unavailable(Self.needsNewerMacOS)
        #endif
    }

    public func prewarm(instructions: String, examples: [PromptExample]) async {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return }
        Self.session(instructions: instructions, examples: examples).prewarm()
        #endif
    }

    public func respond(instructions: String, examples: [PromptExample], prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { throw LLMError.unavailable(Self.needsNewerMacOS) }
        let session = Self.session(instructions: instructions, examples: examples)
        do {
            // Greedy sampling keeps the same transcript producing the same text.
            return try await session.respond(to: prompt, options: GenerationOptions(sampling: .greedy)).content
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.map(error)
        } catch {
            throw Self.map(error as NSError)
        }
        #else
        throw LLMError.unavailable(Self.needsNewerMacOS)
        #endif
    }

    static let needsNewerMacOS = "On-device cleanup needs macOS 26 or later"
    static let assetsNotReady = "Apple Intelligence is still preparing its models. Try again in a few minutes."

    /// Failures that come back as plain NSErrors. Asset problems in the safety classifier or the model
    /// manager mean the system is not ready yet; everything else keeps its domain and code.
    static func map(_ error: NSError) -> LLMError {
        var seen: [NSError] = []
        var queue = [error]
        while let next = queue.popLast() {
            seen.append(next)
            queue += (next.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError]) ?? []
            if let underlying = next.userInfo[NSUnderlyingErrorKey] as? NSError {
                queue.append(underlying)
            }
        }
        let domains = seen.map(\.domain)
        if domains.contains(where: { $0.contains("ModelManager") || $0.contains("SensitiveContentAnalysis") }) {
            return .unavailable(assetsNotReady)
        }
        let deepest = seen.last ?? error
        return .failed("\(deepest.domain) \(deepest.code)")
    }

    #if canImport(FoundationModels)
    /// The examples go in as earlier turns of the conversation, which is what the model follows best.
    @available(macOS 26, *)
    static func session(instructions: String, examples: [PromptExample]) -> LanguageModelSession {
        func segment(_ text: String) -> FoundationModels.Transcript.Segment {
            .text(FoundationModels.Transcript.TextSegment(content: text))
        }
        var entries: [FoundationModels.Transcript.Entry] = [
            .instructions(FoundationModels.Transcript.Instructions(
                segments: [segment(instructions)],
                toolDefinitions: []
            )),
        ]
        for example in examples {
            entries.append(.prompt(FoundationModels.Transcript.Prompt(segments: [segment(example.transcript)])))
            entries.append(.response(FoundationModels.Transcript.Response(
                assetIDs: [],
                segments: [segment(example.formatted)]
            )))
        }
        return LanguageModelSession(transcript: FoundationModels.Transcript(entries: entries))
    }

    @available(macOS 26, *)
    static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled: "Turn on Apple Intelligence in System Settings to clean up text on device"
        case .deviceNotEligible: "This Mac does not support Apple Intelligence"
        case .modelNotReady: "The Apple Intelligence model is still downloading"
        @unknown default: "Apple Intelligence is not available"
        }
    }

    @available(macOS 26, *)
    static func map(_ error: LanguageModelSession.GenerationError) -> LLMError {
        switch error {
        case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale:
            .refused(error.localizedDescription)
        case .exceededContextWindowSize:
            .failed("The dictation is too long for on-device cleanup")
        default:
            .failed(error.localizedDescription)
        }
    }
    #endif
}
