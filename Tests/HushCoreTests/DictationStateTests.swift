import XCTest
@testable import HushCore

final class DictationStateTests: XCTestCase {
    func testForwardPipelineTransitionsAreAllowed() {
        XCTAssertTrue(DictationState.idle.canTransition(to: .listening))
        XCTAssertTrue(DictationState.listening.canTransition(to: .transcribing))
        XCTAssertTrue(DictationState.transcribing.canTransition(to: .idle))
    }

    func testCancelReturnsFromListeningToIdle() {
        XCTAssertTrue(DictationState.listening.canTransition(to: .idle))
    }

    func testSkippingOrReversingStepsIsRejected() {
        XCTAssertFalse(DictationState.idle.canTransition(to: .transcribing))
        XCTAssertFalse(DictationState.transcribing.canTransition(to: .listening))
        XCTAssertFalse(DictationState.listening.canTransition(to: .listening))
        XCTAssertFalse(DictationState.idle.canTransition(to: .idle))
    }

    func testEveryStateCanFail() {
        for state in [DictationState.idle, .listening, .transcribing, .error("first")] {
            XCTAssertTrue(state.canTransition(to: .error("boom")), "\(state)")
        }
    }

    func testErrorRecoversToIdleOrANewDictation() {
        XCTAssertTrue(DictationState.error("x").canTransition(to: .idle))
        XCTAssertTrue(DictationState.error("x").canTransition(to: .listening))
        XCTAssertFalse(DictationState.error("x").canTransition(to: .transcribing))
    }

    func testBusyStates() {
        XCTAssertTrue(DictationState.listening.isBusy)
        XCTAssertTrue(DictationState.transcribing.isBusy)
        XCTAssertFalse(DictationState.idle.isBusy)
        XCTAssertFalse(DictationState.error("x").isBusy)
    }
}
