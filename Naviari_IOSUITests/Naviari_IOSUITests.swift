import XCTest

final class Naviari_IOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeScreenShowsPrimaryCTA() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to use Naviari system. This app is for race managers and boats participating in races. Please start by selecting the race and start."].exists)
        XCTAssertTrue(app.buttons["Open races"].exists)
    }

    @MainActor
    func testTappingOpenRacesShowsRaceListTitle() throws {
        let app = XCUIApplication()
        app.launch()

        let openRacesButton = app.buttons["Open races"]
        XCTAssertTrue(openRacesButton.waitForExistence(timeout: 2))
        openRacesButton.tap()

        let racesTitle = app.staticTexts["Races"]
        XCTAssertTrue(racesTitle.waitForExistence(timeout: 2))
    }
}
