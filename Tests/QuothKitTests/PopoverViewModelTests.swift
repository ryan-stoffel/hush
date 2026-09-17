import QuothCore
import XCTest
@testable import QuothKit

@MainActor
final class PopoverViewModelTests: XCTestCase {
    func testFollowsAppState() {
        let state = AppState()
        let model = PopoverViewModel(
            appState: state,
            permissions: FakePermissions.allGranted,
            version: "1",
            copyText: { _ in },
            quitApp: {}
        )
        XCTAssertTrue(model.presentation.showsEmptyHint)

        state.lastDictation = "Hello"
        state.transition(to: .listening)
        XCTAssertEqual(model.presentation.lastDictation, "Hello")
        XCTAssertEqual(model.presentation.statusText, "Listening")
    }

    func testCopyPassesTheLastDictation() {
        var copied: [String] = []
        let model = PopoverViewModel(
            appState: AppState(lastDictation: "Copy me"),
            permissions: FakePermissions.allGranted,
            version: "1",
            copyText: { copied.append($0) },
            quitApp: {}
        )
        model.copyLastDictation()
        XCTAssertEqual(copied, ["Copy me"])
    }

    func testCopyDoesNothingWithoutADictation() {
        var copied: [String] = []
        let model = PopoverViewModel(
            appState: AppState(),
            permissions: FakePermissions.allGranted,
            version: "1", copyText: { copied.append($0) }, quitApp: {}
        )
        model.copyLastDictation()
        XCTAssertTrue(copied.isEmpty)
    }

    func testQuitCallsTheInjectedAction() {
        var quitCount = 0
        let model = PopoverViewModel(
            appState: AppState(),
            permissions: FakePermissions.allGranted,
            version: "1",
            copyText: { _ in },
            quitApp: { quitCount += 1 }
        )
        model.quit()
        XCTAssertEqual(quitCount, 1)
    }

    func testEveryDemoSceneHasAUniqueName() {
        XCTAssertEqual(Set(DemoScene.allCases.map(\.rawValue)).count, DemoScene.allCases.count)
    }
}
