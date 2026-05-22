import XCTest

/// XCUITests for CourseLineEditView (S2).
/// Requires a real device with the app launched via UI-test launch arguments.
/// Launch argument: "-UITestCourseLineEdit" with value "startLine" or "finishLine".
final class CourseLineEditUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launchStartLine(
        name: String = "Start Line",
        status: String = "preliminary",
        leftLat: Double = 60.12,
        leftLon: Double = 24.95,
        rightLat: Double = 60.13,
        rightLon: Double = 24.96,
        injectedLocation: (lat: Double, lon: Double)? = nil
    ) {
        var launchArguments = [
            "-UITestCourseLineEdit", "startLine",
            "-UITestLineName", name,
            "-UITestLineStatus", status,
            "-UITestLineLeftLat", "\(leftLat)",
            "-UITestLineLeftLon", "\(leftLon)",
            "-UITestLineRightLat", "\(rightLat)",
            "-UITestLineRightLon", "\(rightLon)"
        ]
        if let injectedLocation {
            launchArguments += [
                "-UITestLocationLat", "\(injectedLocation.lat)",
                "-UITestLocationLon", "\(injectedLocation.lon)"
            ]
        }
        app.launchArguments = launchArguments
        app.launch()
    }

    private func launchFinishLine(name: String = "Finish Line") {
        app.launchArguments = [
            "-UITestCourseLineEdit", "finishLine",
            "-UITestLineName", name
        ]
        app.launch()
    }

    // MARK: - Tests

    func testLineEditView_saveButtonExists() {
        launchStartLine()
        XCTAssertTrue(app.buttons["course_edit_save_button"].waitForExistence(timeout: 5))
    }

    func testLineEditView_removeButtonAbsent() {
        launchStartLine()
        _ = app.buttons["course_edit_save_button"].waitForExistence(timeout: 5)
        XCTAssertFalse(app.buttons["course_edit_remove_button"].exists,
                       "Remove button should not exist on line edit form")
    }

    func testLineEditView_roundingControlAbsent() {
        launchStartLine()
        _ = app.buttons["course_edit_save_button"].waitForExistence(timeout: 5)
        XCTAssertFalse(app.otherElements["course_edit_rounding_control"].exists,
                       "Rounding control should not appear on line edit form")
    }

    func testLineEditView_leftEndGPSButtonExists() {
        launchStartLine()
        XCTAssertTrue(app.buttons["course_edit_gps_left"].waitForExistence(timeout: 5))
    }

    func testLineEditView_rightEndGPSButtonExists() {
        launchStartLine()
        XCTAssertTrue(app.buttons["course_edit_gps_right"].waitForExistence(timeout: 5))
    }

    func testLineEditView_leftLatDMSExists() {
        launchStartLine()
        XCTAssertTrue(app.otherElements["left_dms_lat"].waitForExistence(timeout: 5))
    }

    func testLineEditView_rightLatDMSExists() {
        launchStartLine()
        XCTAssertTrue(app.otherElements["right_dms_lat"].waitForExistence(timeout: 5))
    }

    func testLineEditView_leftAndRightDMSFieldsAreDistinct() {
        launchStartLine()
        let leftDMS = app.otherElements["left_dms_lat"]
        let rightDMS = app.otherElements["right_dms_lat"]
        XCTAssertTrue(leftDMS.waitForExistence(timeout: 5))
        XCTAssertTrue(rightDMS.exists)
        // They must be different elements (different frames or identifiers).
        XCTAssertNotEqual(leftDMS.frame, rightDMS.frame,
                          "Left and right DMS lat fields must be at different positions")
    }

    func testLineEditView_formPreFillsLeftEndFromExistingLine() {
        launchStartLine(leftLat: 60.12)
        let leftDMS = app.otherElements["left_dms_lat"]
        XCTAssertTrue(leftDMS.waitForExistence(timeout: 5))
        let degField = leftDMS.textFields.firstMatch
        let value = degField.value as? String ?? ""
        XCTAssertFalse(value.isEmpty, "Left lat degrees should be pre-filled from existing line")
    }

    func testLineEditView_formPreFillsRightEndFromExistingLine() {
        launchStartLine(rightLat: 60.13)
        let rightDMS = app.otherElements["right_dms_lat"]
        XCTAssertTrue(rightDMS.waitForExistence(timeout: 5))
        let degField = rightDMS.textFields.firstMatch
        let value = degField.value as? String ?? ""
        XCTAssertFalse(value.isEmpty, "Right lat degrees should be pre-filled from existing line")
    }

    func testLineEditView_editingLeftEndDoesNotClearRightEnd() {
        launchStartLine(leftLat: 60.12, rightLat: 60.13)
        let rightDMS = app.otherElements["right_dms_lat"]
        XCTAssertTrue(rightDMS.waitForExistence(timeout: 5))
        let rightDegBefore = rightDMS.textFields.firstMatch.value as? String ?? ""

        // Type into left lat degrees field.
        let leftDMS = app.otherElements["left_dms_lat"]
        leftDMS.textFields.firstMatch.tap()
        leftDMS.textFields.firstMatch.typeText("59")

        let rightDegAfter = rightDMS.textFields.firstMatch.value as? String ?? ""
        XCTAssertEqual(rightDegBefore, rightDegAfter,
                       "Editing left end should not clear right end fields")
    }

    func testLineEditView_titleIsCorrectForStartLine() {
        launchStartLine()
        let expectedTitle = NSLocalizedString("course_item_edit_start_line_title", comment: "")
        let titleText = app.staticTexts[expectedTitle]
        XCTAssertTrue(titleText.waitForExistence(timeout: 5),
                      "Screen title should match start line localisation key")
    }

    func testLineEditView_titleIsCorrectForFinishLine() {
        launchFinishLine()
        let expectedTitle = NSLocalizedString("course_item_edit_finish_line_title", comment: "")
        let titleText = app.staticTexts[expectedTitle]
        XCTAssertTrue(titleText.waitForExistence(timeout: 5),
                      "Screen title should match finish line localisation key")
    }

    func testLineEditView_saveButtonDisabledWhenNameIsEmpty() {
        launchStartLine(name: "Start Line")
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearText()
        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when name is empty")
    }

    func testLineEditView_leftGPSButtonPopulatesCoordinateFields() {
        launchStartLine(injectedLocation: (lat: 62.25, lon: 26.5))

        let gpsButton = app.buttons["course_edit_gps_left"]
        XCTAssertTrue(gpsButton.waitForExistence(timeout: 5))
        gpsButton.tap()

        let latDegrees = app.otherElements["left_dms_lat"].textFields.firstMatch
        let lonDegrees = app.otherElements["left_dms_lon"].textFields.firstMatch
        XCTAssertEqual(latDegrees.value as? String, "62")
        XCTAssertEqual(lonDegrees.value as? String, "26")
    }

    func testLineEditView_invalidCoordinateShowsValidationError() {
        launchStartLine()

        let leftLatDegrees = app.otherElements["left_dms_lat"].textFields.firstMatch
        XCTAssertTrue(leftLatDegrees.waitForExistence(timeout: 5))
        leftLatDegrees.tap()
        leftLatDegrees.clearText()
        leftLatDegrees.typeText("91")

        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
    }

    func testLineEditView_saveErrorBannerShownOnFailure() {
        app.launchArguments = [
            "-UITestCourseLineEdit", "startLine",
            "-UITestLineName", "Start Line",
            "-UITestSimulateSaveError", "1"
        ]
        app.launch()
        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
    }
}

