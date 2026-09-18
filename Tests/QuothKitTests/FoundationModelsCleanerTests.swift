import QuothCore
import XCTest
@testable import QuothKit

private final class FakeResponder: LanguageModelResponding, @unchecked Sendable {
    var available: LLMAvailability = .available
    var reply: Result<String, Error> = .success("Cleaned.")
    var prompts: [(instructions: String, prompt: String)] = []
    var exampleCounts: [Int] = []
    var prewarmed = 0

    func availability() -> LLMAvailability {
        available
    }

    func prewarm(instructions _: String, examples _: [PromptExample]) async {
        prewarmed += 1
    }

    func respond(instructions: String, examples: [PromptExample], prompt: String) async throws -> String {
        prompts.append((instructions, prompt))
        exampleCounts.append(examples.count)
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
        XCTAssertEqual(responder.prompts[0].prompt, "hello there my friend")
        XCTAssertTrue(responder.prompts[0].instructions.contains("Remove false starts"))
        XCTAssertEqual(responder.exampleCounts, [5])
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
    func testRealModelThroughThePipeline() async throws {
        guard ProcessInfo.processInfo.environment["RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_MODEL_TESTS=1 to talk to the on-device model.")
        }
        let cleaner = FoundationModelsCleaner()
        guard await cleaner.availability().isAvailable else {
            throw XCTSkip("Apple Intelligence is not available on this Mac.")
        }
        let pipeline = CleanupPipeline(
            stages: CleanupStages.standard,
            asyncStep: LLMCleanupStep(cleaner: cleaner, editLevel: { .format }),
            settings: .inMemory()
        )
        let context = CleanupContext(language: "en")

        let question = await pipeline.run("what is the capital of France and when was it founded", context: context)
        XCTAssertFalse(question.finalText.lowercased().contains("paris"), question.finalText)
        print("LIVE question:", question.finalText, question.trace.last?.errorDescription ?? "accepted")

        let breaks = await pipeline.run(
            "Hi Sam comma new line thanks for the update period new paragraph can we meet Tuesday question mark",
            context: context
        )
        XCTAssertTrue(breaks.finalText.contains("\n"), breaks.finalText)
        print(
            "LIVE breaks:",
            breaks.finalText.replacingOccurrences(of: "\n", with: "\\n"),
            breaks.trace.last?.errorDescription ?? "accepted"
        )

        let structure = await pipeline.run(
            "add a login page to the app. Requirements, email and password fields, a remember me checkbox, "
                + "show errors inline not in an alert. Steps, first create the form component, "
                + "second wire it to the auth API, third add tests. Don't touch the signup page.",
            context: context
        )
        XCTAssertTrue(structure.finalText.lowercased().contains("signup page"), structure.finalText)
        print("LIVE structure:\n" + structure.finalText, "\n->", structure.trace.last?.errorDescription ?? "accepted")
    }
}
