import Foundation

/// The optional model-backed pass at the end of the pipeline. Any failure leaves the rule-based text.
public final class LLMCleanupStep: AsyncCleanupStep, @unchecked Sendable {
    public static let stageID = "llm"

    public let id = LLMCleanupStep.stageID
    private let cleaner: any LLMCleaner
    private let editLevel: @Sendable () -> EditLevel

    public init(cleaner: any LLMCleaner, editLevel: @escaping @Sendable () -> EditLevel = { .light }) {
        self.cleaner = cleaner
        self.editLevel = editLevel
    }

    public func process(_ text: String, context: CleanupContext) async throws -> String {
        guard !LLMOutputGuard.shouldSkip(text) else { return text }
        let request = LLMCleanupRequest(
            text: text,
            language: context.language,
            dictionaryTerms: context.dictionary,
            editLevel: editLevel()
        )
        let output = try await cleaner.clean(request)
        return try LLMOutputGuard.validate(output: output, input: text, dictionaryTerms: context.dictionary)
    }
}
