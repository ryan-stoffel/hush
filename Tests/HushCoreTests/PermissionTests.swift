import XCTest
@testable import HushCore

final class PermissionTests: XCTestCase {
    func testMicrophoneAuthorizationMapping() {
        XCTAssertEqual(PermissionStatus(microphone: .authorized), .granted)
        XCTAssertEqual(PermissionStatus(microphone: .notDetermined), .notDetermined)
        XCTAssertEqual(PermissionStatus(microphone: .denied), .denied)
        XCTAssertEqual(PermissionStatus(microphone: .restricted), .denied)
    }

    func testTrustMapping() {
        XCTAssertEqual(PermissionStatus(isTrusted: true), .granted)
        XCTAssertEqual(PermissionStatus(isTrusted: false), .denied)
    }

    func testMissingKeepsGrantOrderAndTreatsUnknownAsMissing() {
        let snapshot: [Permission: PermissionStatus] = [.accessibility: .denied, .inputMonitoring: .granted]
        XCTAssertEqual(PermissionSummary.missing(in: snapshot), [.microphone, .accessibility])
    }

    func testSummaryMessage() {
        XCTAssertNil(PermissionSummary.message(forMissing: []))
        XCTAssertEqual(PermissionSummary.message(forMissing: [.microphone]), "Microphone access is needed.")
        XCTAssertEqual(
            PermissionSummary.message(forMissing: [.microphone, .accessibility]),
            "Microphone and Accessibility access is needed."
        )
    }

    func testEveryPermissionHasASettingsLinkAndCopy() {
        for permission in Permission.allCases {
            XCTAssertNotNil(permission.settingsURL)
            XCTAssertFalse(permission.displayName.isEmpty)
            XCTAssertFalse(permission.reason.isEmpty)
        }
    }

    func testPopoverListsMissingPermissions() {
        let presentation = PopoverPresentation(
            state: .idle,
            lastDictation: nil,
            version: "1",
            permissions: [.microphone: .granted, .accessibility: .denied, .inputMonitoring: .notDetermined]
        )
        XCTAssertEqual(presentation.missingPermissions, [.accessibility, .inputMonitoring])
    }
}
