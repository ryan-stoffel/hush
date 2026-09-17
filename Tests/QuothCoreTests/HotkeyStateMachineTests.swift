import XCTest
@testable import QuothCore

final class HotkeyStateMachineTests: XCTestCase {
    private let functionKey = HotkeyStateMachine.functionKeyCode

    private func run(_ inputs: [KeyInput], minimumHold: TimeInterval = 0.15) -> [HotkeyEvent] {
        var machine = HotkeyStateMachine(minimumHold: minimumHold)
        return inputs.compactMap { machine.handle($0) }
    }

    func testHoldEmitsPressedThenReleased() {
        let events = run([
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 10.0),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 11.2),
        ])
        XCTAssertEqual(events, [.pressed, .released])
    }

    func testQuickTapIsCancelled() {
        let events = run([
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 10.0),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 10.1),
        ])
        XCTAssertEqual(events, [.pressed, .cancelled])
    }

    func testAnotherKeyDuringTheHoldCancelsAndNeverReleases() {
        let events = run([
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 10.0),
            .keyDown(keyCode: 123, time: 10.5),
            .keyDown(keyCode: 123, time: 10.6),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 11.0),
        ])
        XCTAssertEqual(events, [.pressed, .cancelled])
    }

    func testFunctionWithAnotherModifierDoesNotStart() {
        let events = run([
            .flagsChanged(keyCode: 59, modifiers: .control, time: 10.0),
            .flagsChanged(keyCode: functionKey, modifiers: [.control, .function], time: 10.1),
            .flagsChanged(keyCode: functionKey, modifiers: .control, time: 11.0),
        ])
        XCTAssertEqual(events, [])
    }

    func testAddingAModifierDuringTheHoldCancels() {
        let events = run([
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 10.0),
            .flagsChanged(keyCode: 56, modifiers: [.function, .shift], time: 10.4),
            .flagsChanged(keyCode: 56, modifiers: .function, time: 10.6),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 11.0),
        ])
        XCTAssertEqual(events, [.pressed, .cancelled])
    }

    func testArrowKeysThatCarryTheFunctionFlagDoNotStart() {
        let events = run([
            .flagsChanged(keyCode: 123, modifiers: .function, time: 10.0),
            .keyDown(keyCode: 123, time: 10.0),
        ])
        XCTAssertEqual(events, [])
    }

    func testTypingWithoutAHoldEmitsNothing() {
        XCTAssertEqual(run([.keyDown(keyCode: 0, time: 1), .keyDown(keyCode: 1, time: 2)]), [])
    }

    func testANewHoldWorksAfterACancelledOne() {
        let events = run([
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 10.0),
            .keyDown(keyCode: 96, time: 10.2),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 10.4),
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 12.0),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 13.0),
        ])
        XCTAssertEqual(events, [.pressed, .cancelled, .pressed, .released])
    }

    func testMinimumHoldIsConfigurable() {
        let inputs: [KeyInput] = [
            .flagsChanged(keyCode: functionKey, modifiers: .function, time: 0),
            .flagsChanged(keyCode: functionKey, modifiers: [], time: 0.3),
        ]
        XCTAssertEqual(run(inputs, minimumHold: 0.5), [.pressed, .cancelled])
        XCTAssertEqual(run(inputs, minimumHold: 0.1), [.pressed, .released])
    }
}
