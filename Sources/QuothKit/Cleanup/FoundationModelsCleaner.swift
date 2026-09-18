import Foundation
import QuothCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Seam around the system model so the cleaner can be tested without Apple Intelligence.
public protocol LanguageModelResponding: Sendable {
    func availability() -> LLMAvailability
    func prewarm(instructions: String) async
    func respond(instructions: String, prompt: String) async throws -> String
}

/// On-device cleanup through Apple's Foundation Models framework. Nothing leaves the machine.
/// A fresh session is used for every dictation so no text carries over between them.
public final class FoundationModelsCleaner: LLMCleaner {
    public let id = "foundation-models"
    public let displayName = "Apple Intelligence (on device)"
    public let isLocal = true

    private let model: any LanguageModelResponding

    public init(model: (any LanguageModelResponding)? = nil) {
        self.model = model ?? SystemLanguageModelResponder()
    }

    public func availability() async -> LLMAvailability {
        model.availability()
    }

    /// Loads the model ahead of the first dictation so the first cleanup is not slow.
    public func prewarm() async {
        guard model.availability().isAvailable else { return }
        await model.prewarm(instructions: PromptBuilder.instructions(for: LLMCleanupRequest(text: "")))
    }

    public func clean(_ request: LLMCleanupRequest) async throws -> String {
        if case let .unavailable(reason) = model.availability() {
            throw LLMError.unavailable(reason)
        }
        return try await model.respond(
            instructions: PromptBuilder.instructions(for: request),
            prompt: PromptBuilder.message(for: request)
        )
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

    public func prewarm(instructions: String) async {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return }
        LanguageModelSession(instructions: instructions).prewarm()
        #endif
    }

    public func respond(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { throw LLMError.unavailable(Self.needsNewerMacOS) }
        let session = LanguageModelSession(instructions: instructions)
        do {
            return try await session.respond(to: prompt).content
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.map(error)
        } catch {
            throw LLMError.failed(error.localizedDescription)
        }
        #else
        throw LLMError.unavailable(Self.needsNewerMacOS)
        #endif
    }

    static let needsNewerMacOS = "On-device cleanup needs macOS 26 or later"

    #if canImport(FoundationModels)
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
