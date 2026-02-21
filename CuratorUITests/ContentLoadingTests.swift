import XCTest

@MainActor
final class ContentLoadingTests: XCTestCase {

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

    // MARK: - Home Tab Content

    func testHomeTabDisplaysMediaShelves() {
        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible after launch")
            return
        }

        // Wait for at least one media shelf to appear (content loaded from Overseerr)
        let shelf = app.descendants(matching: .any).matching(identifier: "media_shelf").firstMatch
        XCTAssertTrue(
            shelf.waitForExistence(timeout: 15),
            "At least one media shelf should appear on the Home tab — no content loaded from Overseerr"
        )
    }

    // MARK: - Browse Tab Content

    func testBrowseTabDisplaysGenres() {
        let remote = XCUIRemote.shared

        let homeTab = app.descendants(matching: .any).matching(identifier: "tab_home").firstMatch
        guard homeTab.waitForExistence(timeout: 10) else {
            XCTFail("Home tab not visible after launch")
            return
        }

        // Navigate to Browse tab
        remote.press(.right)

        let browseTab = app.descendants(matching: .any).matching(identifier: "tab_browse").firstMatch
        guard browseTab.waitForExistence(timeout: 5) else {
            XCTFail("Browse tab not reachable")
            return
        }

        // Wait for genre grid to appear (content loaded from Overseerr)
        let genreGrid = app.descendants(matching: .any).matching(identifier: "genre_grid").firstMatch
        XCTAssertTrue(
            genreGrid.waitForExistence(timeout: 15),
            "Genre grid should appear on the Browse tab — no content loaded from Overseerr"
        )
    }
}
