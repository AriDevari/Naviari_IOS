import XCTest

final class BuoySectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(scenario: String) {
        app.launchArguments = ["-UITestBuoySectionState", scenario]
        app.launch()
    }

    func testBuoySection_emptyStateShowsAddButton() {
        launch(scenario: "empty")
        XCTAssertTrue(app.buttons["buoy_add_button"].waitForExistence(timeout: 5))
    }

    func testBuoySection_emptyStateExplainsLocalStorage() {
        launch(scenario: "empty")
        XCTAssertTrue(app.staticTexts["buoy_empty_message"].waitForExistence(timeout: 5))
    }

    func testBuoySection_listStateShowsBuoyRows() {
        launch(scenario: "list")
        XCTAssertTrue(app.buttons["buoy_row_expand_button_buoy-alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["buoy_row_expand_button_buoy-beta"].exists)
    }

    func testBuoySection_rowExpandShowsMetadata() {
        launch(scenario: "list")
        let button = app.buttons["buoy_row_expand_button_buoy-alpha"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        XCTAssertTrue(app.staticTexts["buoy_row_latitude_buoy-alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["buoy_row_longitude_buoy-alpha"].exists)
        XCTAssertTrue(app.staticTexts["buoy_row_last_updated_buoy-alpha"].exists)
    }

    func testBuoySection_onlyOneRowExpandedAtATime() {
        launch(scenario: "list")
        let alphaButton = app.buttons["buoy_row_expand_button_buoy-alpha"]
        let betaButton = app.buttons["buoy_row_expand_button_buoy-beta"]

        XCTAssertTrue(alphaButton.waitForExistence(timeout: 5))
        alphaButton.tap()
        XCTAssertTrue(app.staticTexts["buoy_row_latitude_buoy-alpha"].waitForExistence(timeout: 5))

        betaButton.tap()
        XCTAssertFalse(app.staticTexts["buoy_row_latitude_buoy-alpha"].exists)
        XCTAssertTrue(app.staticTexts["buoy_row_latitude_buoy-beta"].waitForExistence(timeout: 5))
    }

    func testBuoySection_rowsHaveNoConnectorRail() {
        launch(scenario: "list")
        XCTAssertFalse(app.otherElements["buoy_section_rail"].exists)
    }
}
