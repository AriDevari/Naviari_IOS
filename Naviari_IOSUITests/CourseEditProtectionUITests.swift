import XCTest

final class CourseEditProtectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testNoTokenPathShowsManageCodeModalBeforeEditSheet() {
        app.launchArguments = [
            "-UITestCourseEditProtectionHost", "1"
        ]
        app.launch()

        let openButton = app.buttons["course_test_open_edit_button"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        openButton.tap()

        let expectedTitle = NSLocalizedString("set_start_time_manage_code_title", comment: "")
        XCTAssertTrue(app.navigationBars[expectedTitle].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["course_edit_save_button"].exists)
    }
}