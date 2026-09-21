import AVFoundation
import HushCore
import XCTest
@testable import HushKit

@MainActor
final class PermissionsTests: XCTestCase {
    func testAVAuthorizationStatusMapping() {
        XCTAssertEqual(SystemPermissionsService.authorization(from: .authorized), .authorized)
        XCTAssertEqual(SystemPermissionsService.authorization(from: .denied), .denied)
        XCTAssertEqual(SystemPermissionsService.authorization(from: .restricted), .restricted)
        XCTAssertEqual(SystemPermissionsService.authorization(from: .notDetermined), .notDetermined)
    }

    func testGrantRequestsThenRefreshes() async {
        let fake = FakePermissions(statuses: [.microphone: .notDetermined])
        let state = AppState()
        let model = PopoverViewModel(appState: state, permissions: fake, version: "1", copyText: { _ in }, quitApp: {})
        XCTAssertEqual(model.presentation.missingPermissions, Permission.allCases)

        await model.grant(.microphone)
        XCTAssertEqual(fake.requested, [.microphone])
        XCTAssertTrue(fake.openedSettings.isEmpty)
        XCTAssertEqual(state.permissions[.microphone], .granted)
    }

    func testDeniedPermissionOpensSystemSettings() async {
        let fake = FakePermissions(statuses: [.accessibility: .denied], grantsOnRequest: false)
        let model = PopoverViewModel(
            appState: AppState(),
            permissions: fake,
            version: "1",
            copyText: { _ in },
            quitApp: {}
        )
        await model.grant(.accessibility)
        XCTAssertEqual(fake.openedSettings, [.accessibility])
    }

    func testDemoPermissionsNeverNeedTheSystem() {
        XCTAssertTrue(PermissionSummary.missing(in: DemoData.permissions(for: .popover).snapshot()).isEmpty)
        XCTAssertEqual(
            PermissionSummary.missing(in: DemoData.permissions(for: .popoverPermissions).snapshot()),
            [.microphone, .accessibility]
        )
    }
}
