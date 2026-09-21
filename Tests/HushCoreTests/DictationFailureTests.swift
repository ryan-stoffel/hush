import XCTest
@testable import HushCore

final class DictationFailureTests: XCTestCase {
    func testMessagesAreSpecific() {
        XCTAssertEqual(DictationFailure.message(for: AudioCaptureError.noInputDevice), "No microphone found")
        XCTAssertEqual(
            DictationFailure.message(for: TranscriptionError.unsupportedHardware),
            "On-device transcription needs Apple silicon"
        )
        XCTAssertEqual(
            DictationFailure.message(for: InsertionError.accessibilityNotGranted),
            "Accessibility access is off"
        )
        XCTAssertEqual(DictationFailure.message(for: HotkeyError.eventTapUnavailable), "Input Monitoring access is off")
        XCTAssertEqual(DictationFailure.message(for: CocoaError(.fileNoSuchFile)), "Something went wrong")
    }

    func testMissingPermissionMessageNamesTheFirstOne() {
        XCTAssertNil(DictationFailure.message(forMissing: []))
        XCTAssertEqual(
            DictationFailure.message(forMissing: [.accessibility, .inputMonitoring]),
            "Accessibility access is off"
        )
    }
}
