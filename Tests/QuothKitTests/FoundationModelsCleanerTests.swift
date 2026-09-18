import QuothCore
import XCTest
@testable import QuothKit

private final class FakeResponder: LanguageModelResponding, @unchecked Sendable {
    var available: LLMAvailability = .available
    var reply: Result<String, Error> = .success("Cleaned.")
    var prompts: [(instructions: String, prompt: String)] = []
    var prewarmed = 0

    func availability() -> LLMAvailability {
        available
    }

    func prewarm(instructions _: String) async {
        prewarmed += 1
    }

    func respond(instructions: String, prompt: String) async throws -> String {
        prompts.append((instructions, prompt))
        return try reply.get()
    }
}

final class FoundationModelsCleanerTests: XCTestCase {
    func testUsesFreshDelimitedPromptPerRequest() async throws {
        let responder = FakeResponder()
        let cleaner = FoundationModelsCleaner(model: responder)
        let output = try await cleaner.clean(LLMCleanupRequest(text: "hello there my friend", editLevel: .medium))
        XCTAssertEqual(output, "Cleaned.")
        XCTAssertEqual(responder.prompts.count, 1)
        XCTAssertTrue(responder.prompts[0].prompt.contains("<<<TRANSCRIPT\nhello there my friend\nTRANSCRIPT>>>"))
        XCTAssertTrue(responder.prompts[0].instructions.contains("Remove false starts"))
        XCTAssertTrue(cleaner.isLocal)
    }

    func testUnavailableModelThrowsInsteadOfPrompting() async {
        let responder = FakeResponder()
        responder.available = .unavailable("Turn on Apple Intelligence")
        let cleaner = FoundationModelsCleaner(model: responder)
        do {
            _ = try await cleaner.clean(LLMCleanupRequest(text: "hello there my friend"))
            XCTFail("expected unavailable")
        } catch {
            XCTAssertEqual(error as? LLMError, .unavailable("Turn on Apple Intelligence"))
        }
        XCTAssertTrue(responder.prompts.isEmpty)
        await cleaner.prewarm()
        XCTAssertEqual(responder.prewarmed, 0)
    }

    func testPrewarmOnlyWhenAvailable() async {
        let responder = FakeResponder()
        await FoundationModelsCleaner(model: responder).prewarm()
        XCTAssertEqual(responder.prewarmed, 1)
    }

    func testFailuresFallBackThroughThePipeline() async {
        let responder = FakeResponder()
        responder.reply = .failure(LLMError.refused("guardrail"))
        let pipeline = CleanupPipeline(
            stages: [SpokenFormatting()],
            asyncStep: LLMCleanupStep(cleaner: FoundationModelsCleaner(model: responder)),
            settings: .inMemory()
        )
        let result = await pipeline.run("hello there my friend period", context: CleanupContext(language: "en"))
        XCTAssertEqual(result.finalText, "hello there my friend.")
        XCTAssertNotNil(result.trace.last?.errorDescription)
    }

    func testSystemAvailabilityReportsAReadableReason() {
        let availability = SystemLanguageModelResponder().availability()
        if case let .unavailable(reason) = availability {
            XCTAssertFalse(reason.isEmpty)
        }
    }

    /// Talks to the real on-device model. Needs macOS 26 with Apple Intelligence turned on.
    func testRealModelCleansWithoutAnswering() async throws {
        guard ProcessInfo.processInfo.environment["RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_MODEL_TESTS=1 to talk to the on-device model.")
        }
        let cleaner = FoundationModelsCleaner()
        guard await cleaner.availability().isAvailable else {
            throw XCTSkip("Apple Intelligence is not available on this Mac.")
        }
        let input = "what is the capital of france and when was it founded"
        let output = try await cleaner.clean(LLMCleanupRequest(text: input, language: "en"))
        let validated = try LLMOutputGuard.validate(output: output, input: input)
        XCTAssertFalse(validated.lowercased().contains("paris"), validated)
    }
}
