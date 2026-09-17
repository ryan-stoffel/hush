import XCTest
@testable import QuothCore

final class TranscriptionTests: XCTestCase {
    func testSanitizerStripsWhisperMarkers() {
        XCTAssertEqual(TranscriptSanitizer.clean("[BLANK_AUDIO]"), "")
        XCTAssertEqual(TranscriptSanitizer.clean(" Hello [MUSIC] world. "), "Hello world.")
        XCTAssertEqual(TranscriptSanitizer.clean("<|startoftranscript|><|en|> Hi there.<|endoftext|>"), "Hi there.")
        XCTAssertEqual(TranscriptSanitizer.clean("Well (laughs) that works ."), "Well that works.")
        XCTAssertEqual(TranscriptSanitizer.clean("(Music)"), "")
    }

    func testSanitizerKeepsOrdinaryBracketsAndParentheses() {
        XCTAssertEqual(TranscriptSanitizer.clean("Use array[0] here"), "Use array[0] here")
        XCTAssertEqual(TranscriptSanitizer.clean("Ship it (after lunch)."), "Ship it (after lunch).")
        XCTAssertEqual(TranscriptSanitizer.clean("See [1] and [2]."), "See [1] and [2].")
    }

    func testAudioShorterThanTheMinimumIsRejected() {
        XCTAssertThrowsError(try TranscriptionRules.validate(.empty)) {
            XCTAssertEqual($0 as? TranscriptionError, .tooShort)
        }
        XCTAssertThrowsError(try TranscriptionRules.validate(AudioClip(samples: Array(repeating: 0, count: 4000))))
        XCTAssertNoThrow(try TranscriptionRules.validate(AudioClip(samples: Array(repeating: 0, count: 4800))))
    }

    func testDefaultOptionsDetectTheLanguage() {
        XCTAssertNil(TranscriptionOptions.automatic.language)
        XCTAssertTrue(TranscriptionOptions.automatic.vocabulary.isEmpty)
    }
}
