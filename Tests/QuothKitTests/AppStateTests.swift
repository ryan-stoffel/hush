import QuothCore
import XCTest
@testable import QuothKit

@MainActor
final class AppStateTests: XCTestCase {
    func testAllowedTransitionIsPublished() {
        let state = AppState()
        var seen: [DictationState] = []
        let cancellable = state.$dictation.sink { seen.append($0) }
        XCTAssertTrue(state.transition(to: .listening))
        XCTAssertEqual(seen, [.idle, .listening])
        cancellable.cancel()
    }

    func testRejectedTransitionLeavesStateUntouched() {
        let state = AppState()
        XCTAssertFalse(state.transition(to: .transcribing))
        XCTAssertEqual(state.dictation, .idle)
    }

    func testTransitionToTheSameStateIsANoOp() {
        let state = AppState(dictation: .listening)
        XCTAssertTrue(state.transition(to: .listening))
        XCTAssertEqual(state.dictation, .listening)
    }
}
