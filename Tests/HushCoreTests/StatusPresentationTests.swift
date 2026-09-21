import XCTest
@testable import HushCore

final class StatusPresentationTests: XCTestCase {
    private let states: [DictationState] = [.idle, .listening, .transcribing, .error("Microphone access is off")]

    func testEveryStateHasADistinctSymbol() {
        let symbols = states.map { StatusPresentation(state: $0).symbolName }
        XCTAssertEqual(Set(symbols).count, states.count)
        XCTAssertEqual(symbols, ["mic", "mic.fill", "waveform", "exclamationmark.triangle"])
    }

    func testAccessibilityLabelsNameTheAppAndTheState() {
        let labels = states.map { StatusPresentation(state: $0, appName: "Hush").accessibilityLabel }
        XCTAssertEqual(labels, [
            "Hush, ready",
            "Hush, listening",
            "Hush, transcribing",
            "Hush, error: Microphone access is off",
        ])
    }

    func testErrorWithoutMessageGetsAFallbackTitle() {
        XCTAssertEqual(StatusPresentation(state: .error("")).title, "Something went wrong")
    }
}
