import XCTest
@testable import QuothCore

final class InsertionStrategySelectorTests: XCTestCase {
    func testEveryAppUsesClipboardPasteForNow() {
        let selector = InsertionStrategySelector()
        let bundleIdentifiers = [
            "com.apple.TextEdit",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.google.Chrome",
            "com.tinyspeck.slackmacgap",
            "com.microsoft.VSCode",
            nil,
        ]
        for identifier in bundleIdentifiers {
            XCTAssertEqual(selector.strategy(forBundleIdentifier: identifier), .clipboardPaste, identifier ?? "nil")
        }
    }

    func testStrategyRawValuesAreStableForHistory() {
        XCTAssertEqual(InsertionStrategy.clipboardPaste.rawValue, "clipboardPaste")
        XCTAssertEqual(InsertionStrategy.accessibility.rawValue, "accessibility")
    }
}
