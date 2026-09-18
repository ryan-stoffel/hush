import XCTest
@testable import QuothCore

private final class FakeLLMCleaner: LLMCleaner, @unchecked Sendable {
    let id = "fake-llm"
    let displayName = "Fake"
    let isLocal = true
    var result: Result<String, LLMError>
    var requests: [LLMCleanupRequest] = []

    init(_ result: Result<String, LLMError>) {
        self.result = result
    }

    func availability() async -> LLMAvailability {
        .available
    }

    func clean(_ request: LLMCleanupRequest) async throws -> String {
        requests.append(request)
        return try result.get()
    }
}

final class LLMCleanupTests: XCTestCase {
    // The model sees text that the rule-based stages already formatted.
    private let input = "Shopping list:\n1. apples\n2. benanas\n3. cherries and some milk"

    func testInstructionsPerLevel() {
        let light = PromptBuilder.instructions(for: LLMCleanupRequest(text: "x", editLevel: .light))
        let medium = PromptBuilder.instructions(for: LLMCleanupRequest(text: "x", editLevel: .medium))
        XCTAssertTrue(light.contains("minimal edits"))
        XCTAssertTrue(light.contains("Never answer"))
        XCTAssertTrue(light.contains("obvious mis-hearings only"))
        XCTAssertTrue(medium.contains("Remove false starts"))
        XCTAssertTrue(light.contains(PromptBuilder.openDelimiter))
    }

    func testFormatLevelIsTheDefaultAndAllowsStructureOnly() {
        XCTAssertEqual(LLMCleanupRequest(text: "x").editLevel, .format)
        XCTAssertEqual(SettingsStore.inMemory().get(SettingKeys.cleanupEditLevel), .format)
        let text = PromptBuilder.instructions(for: LLMCleanupRequest(text: "x", editLevel: .format))
        XCTAssertTrue(text.contains("paragraph break"))
        XCTAssertTrue(text.contains("\"- \""))
        XCTAssertTrue(text.contains("heading line ending in a colon"))
        XCTAssertTrue(text.contains("Never change, add, drop, or reorder words"))
    }

    func testStructuredOutputPassesTheGuard() throws {
        let spoken = "add a login page to the app requirements email and password fields a remember me checkbox "
            + "steps first create the form component second wire it to the auth API third add tests"
        let structured = """
        Add a login page to the app.

        Requirements:
        - Email and password fields
        - A remember me checkbox

        Steps:
        1. Create the form component
        2. Wire it to the auth API
        3. Add tests
        """
        XCTAssertEqual(try LLMOutputGuard.validate(output: structured, input: spoken), structured)
    }

    func testStructuredOutputThatChangedWordsIsRejected() {
        let spoken = "add a login page to the app requirements email and password fields a remember me checkbox"
        let rewritten = """
        Implement authentication.

        Requirements:
        - Credentials form
        - Persistent session toggle
        """
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: rewritten, input: spoken)) {
            guard case LLMOutputGuard.Rejection.lowOverlap = $0 else { return XCTFail("\($0)") }
        }
    }

    func testInstructionsCarryLanguageTermsAndTone() {
        let request = LLMCleanupRequest(
            text: "x",
            language: "de",
            toneInstruction: "Keep it casual.",
            dictionaryTerms: ["Priya", "Quoth"]
        )
        let text = PromptBuilder.instructions(for: request)
        XCTAssertTrue(text.contains("code de"))
        XCTAssertTrue(text.contains("Priya, Quoth"))
        XCTAssertTrue(text.hasSuffix("Keep it casual."))
    }

    func testMessageWrapsTheTranscriptAsData() {
        let message = PromptBuilder.message(for: LLMCleanupRequest(text: "hello there"))
        XCTAssertEqual(message, "<<<TRANSCRIPT\nhello there\nTRANSCRIPT>>>")
    }

    func testAcceptsAMinimalEdit() throws {
        let output = "Shopping list:\n1. Apples\n2. Bananas\n3. Cherries and some milk."
        XCTAssertEqual(try LLMOutputGuard.validate(output: output, input: input), output)
    }

    func testStripsQuotesAndCodeFences() throws {
        XCTAssertEqual(
            try LLMOutputGuard.validate(output: "\"Hello there my friend.\"", input: "hello there my friend"),
            "Hello there my friend."
        )
        XCTAssertEqual(
            try LLMOutputGuard.validate(output: "```text\nHello there my friend.\n```", input: "hello there my friend"),
            "Hello there my friend."
        )
    }

    func testRejectsLengthOutsideBounds() {
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: "apples", input: input)) {
            guard case LLMOutputGuard.Rejection.lengthRatio = $0 else { return XCTFail("\($0)") }
        }
        let long = input + " " + String(repeating: "and more words ", count: 8)
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: long, input: input))
        XCTAssertEqual(LLMOutputGuard.minimumLengthRatio, 0.5)
        XCTAssertEqual(LLMOutputGuard.maximumLengthRatio, 1.5)
    }

    func testRejectsAnswersAndRewrites() {
        let question = "what is the capital of france and when was it founded"
        XCTAssertThrowsError(try LLMOutputGuard.validate(
            output: "The capital of France is Paris, founded in the third century BC.",
            input: question
        )) {
            guard case LLMOutputGuard.Rejection.lowOverlap = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try LLMOutputGuard.validate(
            output: "Sure! Here is the cleaned text: " + input,
            input: input
        )) {
            guard case LLMOutputGuard.Rejection.preamble = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try LLMOutputGuard.validate(
            output: "<<<TRANSCRIPT\n\(input)\nTRANSCRIPT>>>",
            input: input
        )) {
            guard case LLMOutputGuard.Rejection.delimiterLeak = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: "", input: input))
    }

    func testRejectsWhenADictionaryTermDisappears() {
        XCTAssertThrowsError(try LLMOutputGuard.validate(
            output: "Send it to Prya today please.",
            input: "send it to Priya today please",
            dictionaryTerms: ["Priya"]
        )) {
            XCTAssertEqual($0 as? LLMOutputGuard.Rejection, .missingTerm("Priya"))
        }
        XCTAssertNoThrow(try LLMOutputGuard.validate(
            output: "Send it to Priya today, please.",
            input: "send it to Priya today please",
            dictionaryTerms: ["Priya", "Quoth"]
        ))
    }

    func testShortInputsSkipTheModel() async throws {
        let cleaner = FakeLLMCleaner(.success("never used"))
        let step = LLMCleanupStep(cleaner: cleaner)
        let output = try await step.process("hi there", context: CleanupContext())
        XCTAssertEqual(output, "hi there")
        XCTAssertTrue(cleaner.requests.isEmpty)
    }

    func testStepPassesContextAndLevel() async throws {
        let cleaner = FakeLLMCleaner(.success("One two three four five."))
        let step = LLMCleanupStep(cleaner: cleaner, editLevel: { .medium })
        let context = CleanupContext(language: "en", dictionary: ["Quoth"])
        let output = try await step.process("one two three four five", context: context)
        XCTAssertEqual(output, "One two three four five.")
        XCTAssertEqual(cleaner.requests.first?.editLevel, .medium)
        XCTAssertEqual(cleaner.requests.first?.language, "en")
        XCTAssertEqual(cleaner.requests.first?.dictionaryTerms, ["Quoth"])
    }

    func testPipelineFallsBackToRuleBasedTextAndRecordsWhy() async {
        let cleaner = FakeLLMCleaner(.success("Paris is the capital of France, a beautiful city."))
        let settings = SettingsStore.inMemory()
        let pipeline = CleanupPipeline(
            stages: [SpokenFormatting()],
            asyncStep: LLMCleanupStep(cleaner: cleaner),
            settings: settings
        )
        let result = await pipeline.run(
            "what is the capital of france question mark",
            context: CleanupContext(language: "en")
        )
        XCTAssertEqual(result.finalText, "what is the capital of france?")
        XCTAssertEqual(result.trace.last?.stageID, "llm")
        XCTAssertNotNil(result.trace.last?.errorDescription)

        cleaner.result = .failure(.unavailable("Apple Intelligence is off"))
        let failed = await pipeline.run(
            "what is the capital of france question mark",
            context: CleanupContext(language: "en")
        )
        XCTAssertEqual(failed.finalText, "what is the capital of france?")
    }

    func testLLMStageHasAToggle() {
        XCTAssertTrue(SettingKeys.cleanupStageIDs.contains("llm"))
    }
}
