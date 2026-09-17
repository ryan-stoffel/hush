import CoreGraphics
import QuothCore
import XCTest
@testable import QuothKit

final class EventTapHotkeyMonitorTests: XCTestCase {
    func testModifierMapping() {
        XCTAssertEqual(EventTapHotkeyMonitor.modifiers(from: .maskSecondaryFn), .function)
        XCTAssertEqual(
            EventTapHotkeyMonitor.modifiers(from: [.maskSecondaryFn, .maskControl, .maskShift]),
            [.function, .control, .shift]
        )
        XCTAssertEqual(EventTapHotkeyMonitor.modifiers(from: [.maskAlternate, .maskCommand]), [.option, .command])
        XCTAssertEqual(EventTapHotkeyMonitor.modifiers(from: .maskAlphaShift), [])
    }

    func testKeyInputFromEvents() throws {
        let flags = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 63, keyDown: true))
        flags.type = .flagsChanged
        flags.flags = .maskSecondaryFn
        guard case let .flagsChanged(keyCode, modifiers, _)? = EventTapHotkeyMonitor.keyInput(
            type: .flagsChanged,
            event: flags
        ) else {
            return XCTFail("expected flagsChanged")
        }
        XCTAssertEqual(keyCode, 63)
        XCTAssertEqual(modifiers, .function)

        let key = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 123, keyDown: true))
        guard case let .keyDown(code, _)? = EventTapHotkeyMonitor.keyInput(type: .keyDown, event: key) else {
            return XCTFail("expected keyDown")
        }
        XCTAssertEqual(code, 123)
        XCTAssertNil(EventTapHotkeyMonitor.keyInput(type: .keyUp, event: key))
    }

    func testFakeMonitorForwardsEvents() throws {
        let fake = FakeHotkeyMonitor()
        var received: [HotkeyEvent] = []
        fake.onEvent = { received.append($0) }
        try fake.start()
        fake.send(.pressed)
        fake.send(.released)
        XCTAssertTrue(fake.isStarted)
        XCTAssertEqual(received, [.pressed, .released])
    }
}
