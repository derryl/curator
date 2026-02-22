import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testCaptureHomeTab() {
        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Wait for content to load
        sleep(3)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Home Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureBrowseTab() {
        let remote = XCUIRemote.shared

        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate to Browse tab
        remote.press(.right)
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Browse Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureMovieDetail() {
        let remote = XCUIRemote.shared

        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate into content and select first item
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        sleep(3)

        let heroTitle = app.staticTexts.matching(identifier: "hero_title").firstMatch
        if heroTitle.waitForExistence(timeout: 5) {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Movie Detail"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testCaptureSearchTab() {
        let remote = XCUIRemote.shared

        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate to Search tab (Home -> Browse -> Search)
        remote.press(.right)
        remote.press(.right)
        sleep(2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Search Tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
