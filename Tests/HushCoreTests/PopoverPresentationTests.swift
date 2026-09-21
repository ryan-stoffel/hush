import XCTest
@testable import HushCore

final class PopoverPresentationTests: XCTestCase {
    func testStatusTextPerState() {
        let texts = [DictationState.idle, .listening, .transcribing, .error("No microphone")].map {
            PopoverPresentation(state: $0, lastDictation: nil, version: "1").statusText
        }
        XCTAssertEqual(texts, ["Ready", "Listening", "Transcribing", "No microphone"])
    }

    func testEmptyHintWhenThereIsNoDictation() {
        for last in [nil, "", "  \n"] {
            let presentation = PopoverPresentation(state: .idle, lastDictation: last, version: "1")
            XCTAssertTrue(presentation.showsEmptyHint)
            XCTAssertNil(presentation.lastDictation)
        }
    }

    func testLastDictationIsTrimmed() {
        let presentation = PopoverPresentation(state: .idle, lastDictation: " Hello there. \n", version: "0.1.0 (1)")
        XCTAssertEqual(presentation.lastDictation, "Hello there.")
        XCTAssertFalse(presentation.showsEmptyHint)
        XCTAssertEqual(presentation.versionText, "Version 0.1.0 (1)")
    }

    func testOnlyErrorStateIsFlaggedAsError() {
        XCTAssertTrue(PopoverPresentation(state: .error("x"), lastDictation: nil, version: "1").isError)
        XCTAssertFalse(PopoverPresentation(state: .listening, lastDictation: nil, version: "1").isError)
    }
}
