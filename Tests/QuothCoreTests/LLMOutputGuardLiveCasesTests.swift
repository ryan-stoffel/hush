import XCTest
@testable import QuothCore

/// The three dictations that got through the first version of the guard on a real Mac.
final class LLMOutputGuardLiveCasesTests: XCTestCase {
    func testAnswerThatEchoesTheQuestionIsRejected() {
        let question = "what is the capital of france and when was it founded"
        let answer = "Paris is the capital of France and was founded in 508 BCE."
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: answer, input: question)) {
            guard case LLMOutputGuard.Rejection.wordsChanged = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(
            try LLMOutputGuard.validate(
                output: "What is the capital of France and when was it founded?",
                input: question
            ),
            "What is the capital of France and when was it founded?"
        )
    }

    func testMarkdownRewriteIsRejected() {
        let spoken = "add a login page to the app requirements email and password fields a remember me checkbox "
            + "show errors inline not in an alert steps first create the form component second wire it to the auth api "
            + "third add tests don't touch the signup page"
        let rewrite = """
        ### Requirements
        - Login page with email and password fields
        - Remember me checkbox
        - Error handling (inline, not an alert)

        ### Steps
        1. Create the form component
        2. Wire it to the auth API
        3. Add tests
        """
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: rewrite, input: spoken)) {
            guard case LLMOutputGuard.Rejection.markdown = $0 else { return XCTFail("\($0)") }
        }
        let withoutHeadings = rewrite.replacingOccurrences(of: "### ", with: "")
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: withoutHeadings, input: spoken)) {
            guard case LLMOutputGuard.Rejection.wordsChanged = $0 else { return XCTFail("\($0)") }
        }
    }

    func testStructureAroundTheSameWordsPasses() throws {
        let spoken = "add a login page to the app requirements email and password fields a remember me checkbox "
            + "steps first create the form component second wire it to the auth api third add tests"
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

    func testDroppedLineBreaksAreRejected() {
        let input = "Hi Sam,\nThanks for the update.\n\nCan we meet Tuesday?"
        XCTAssertThrowsError(try LLMOutputGuard.validate(
            output: "Hi Sam, thanks for the update. Can we meet Tuesday?",
            input: input
        )) {
            XCTAssertEqual($0 as? LLMOutputGuard.Rejection, .lineBreaksDropped)
        }
        XCTAssertEqual(try LLMOutputGuard.validate(output: input, input: input), input)
    }

    func testSpellingAndPunctuationFixesStillPass() throws {
        XCTAssertEqual(
            try LLMOutputGuard.validate(
                output: "Shopping list:\n1. Apples\n2. Bananas\n3. Cherries",
                input: "Shopping list:\n1. apples\n2. benanas\n3. cherries"
            ),
            "Shopping list:\n1. Apples\n2. Bananas\n3. Cherries"
        )
        XCTAssertEqual(
            try LLMOutputGuard.validate(
                output: "Let's ship it on Wednesday and tell Priya.",
                input: "lets ship it on wednesday and tell priya"
            ),
            "Let's ship it on Wednesday and tell Priya."
        )
    }

    func testReorderedWordsAreRejected() {
        let input = "send the report to sam on wednesday and copy priya on the thread"
        let reordered = "Copy Priya on the thread and send the report to Sam on Wednesday."
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: reordered, input: input)) {
            guard case LLMOutputGuard.Rejection.wordsChanged = $0 else { return XCTFail("\($0)") }
        }
    }

    func testADroppedSentenceOnALongDictationIsRejected() {
        let sentence = "please do not touch the signup page"
        let body = Array(repeating: "we talked about the plan for the release and the follow up work", count: 5)
            .joined(separator: " ")
        let input = body + " " + sentence
        XCTAssertThrowsError(try LLMOutputGuard.validate(output: body.capitalized + ".", input: input)) {
            guard case LLMOutputGuard.Rejection.wordsChanged = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(LLMOutputGuard.maximumChangedWords, 4)
    }

    func testLongestCommonSubsequence() {
        XCTAssertEqual(LLMOutputGuard.longestCommonSubsequence(["a", "b", "c", "d"], ["a", "c", "d"]), 3)
        XCTAssertEqual(LLMOutputGuard.longestCommonSubsequence(["a", "b"], ["b", "a"]), 1)
        XCTAssertEqual(LLMOutputGuard.longestCommonSubsequence([], ["a"]), 0)
    }
}
