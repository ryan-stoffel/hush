import XCTest
@testable import QuothCore

final class StatusPresentationTests: XCTestCase {
    private let states: [DictationState] = [.idle, .listening, .transcribing, .error("Microphone access is off")]

    func testEveryStateHasADistinctSymbol() {
        let symbols = states.map { StatusPresentation(state: $0).symbolName }
        XCTAssertEqual(Set(symbols).count, states.count)
        XCTAssertEqual(symbols, ["mic", "mic.fill", "waveform", "exclamationmark.triangle"])
    }

    func testAccessibilityLabelsNameTheAppAndTheState() {
        let labels = states.map { StatusPresentation(state: $0, appName: "Quoth").accessibilityLabel }
        XCTAssertEqual(labels, [
            "Quoth, ready",
            "Quoth, listening",
            "Quoth, transcribing",
            "Quoth, error: Microphone access is off",
        ])
    }

    func testErrorWithoutMessageGetsAFallbackTitle() {
        XCTAssertEqual(StatusPresentation(state: .error("")).title, "Something went wrong")
    }
}
