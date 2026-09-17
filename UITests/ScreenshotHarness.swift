import XCTest

/// Base class for the screenshot suite. Every test launches the app in demo mode with one
/// scene and attaches a PNG whose attachment name becomes the file name on the screenshots branch.
class ScreenshotTestCase: XCTestCase {
    var app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func launch(scene: String?, extraArguments: [String] = []) {
        app = XCUIApplication()
        var arguments = ["-demoMode", "YES"]
        if let scene {
            arguments += ["-demoScene", scene]
        }
        app.launchArguments = arguments + extraArguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func capture(_ element: XCUIElement, named name: String, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Scene \(name) did not appear")
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
