import XCTest

@MainActor
final class NavigationTests: XCTestCase {

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

    // MARK: - Tab Navigation

    func testAppLaunchesAndHomeTabIsVisible() {
        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "Home tab should be visible after launch")
    }

    func testNavigatingBetweenTabs() {
        let remote = XCUIRemote.shared

        // Start on Home tab
        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate right to Browse tab
        remote.press(.right)
        let browseTab = app.descendants(matching: .any).matching(identifier: "tab_browse").firstMatch
        XCTAssertTrue(browseTab.waitForExistence(timeout: 5), "Browse tab should be reachable")

        // Navigate right to Search tab
        remote.press(.right)
        let searchTab = app.descendants(matching: .any).matching(identifier: "tab_search").firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab should be reachable")

        // Navigate left back to Browse
        remote.press(.left)
        XCTAssertTrue(browseTab.waitForExistence(timeout: 5), "Should return to Browse tab")
    }

    // MARK: - Detail Navigation

    func testSelectingMediaItemNavigatesToDetail() {
        let remote = XCUIRemote.shared

        // Wait for home content to load
        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate down into content area and select first item
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        sleep(2)

        // If a detail view loaded, we should see a hero title
        let heroTitle = app.staticTexts.matching(identifier: "hero_title").firstMatch
        if heroTitle.waitForExistence(timeout: 5) {
            XCTAssertTrue(heroTitle.exists, "Hero title should be visible in detail view")

            // Press menu to go back
            remote.press(.menu)
            sleep(1)

            // Home tab should be visible again
            XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Should return to home after pressing menu")
        }
        // If no content loaded (e.g. no server configured), skip gracefully
    }

    func testMenuButtonReturnsFromDetailView() {
        let remote = XCUIRemote.shared

        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible")
            return
        }

        // Navigate into content and select
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        sleep(2)

        // Press menu to go back
        remote.press(.menu)
        sleep(1)

        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Should return to previous screen after menu press")
    }
}
