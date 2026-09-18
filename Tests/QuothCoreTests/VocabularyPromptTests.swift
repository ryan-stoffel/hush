import XCTest
@testable import QuothCore

final class VocabularyPromptTests: XCTestCase {
    func testPromptIsCommaSeparatedAndDeduplicated() {
        XCTAssertEqual(
            VocabularyPrompt.text(for: ["colon", " Priya ", "colon", "COLON", "new line"]),
            "colon, Priya, new line."
        )
    }

    func testEmptyVocabularyHasNoPrompt() {
        XCTAssertNil(VocabularyPrompt.text(for: []))
        XCTAssertNil(VocabularyPrompt.text(for: ["", "  "]))
    }

    func testTrimKeepsTheNewestTokens() {
        XCTAssertEqual(VocabularyPrompt.trim([1, 2, 3, 4], to: 2), [3, 4])
        XCTAssertEqual(VocabularyPrompt.trim([1, 2], to: 5), [1, 2])
        XCTAssertEqual(VocabularyPrompt.tokenBudget, 111)
    }

    func testSpokenVocabularyCoversEveryCommandPhrase() {
        for phrase in SpokenCommand.phrases {
            XCTAssertTrue(
                SpokenVocabulary.words.contains(phrase.words.joined(separator: " ")),
                phrase.words.joined(separator: " ")
            )
        }
        XCTAssertTrue(SpokenVocabulary.words.contains("colon"))
        XCTAssertNotNil(VocabularyPrompt.text(for: SpokenVocabulary.words))
    }
}
