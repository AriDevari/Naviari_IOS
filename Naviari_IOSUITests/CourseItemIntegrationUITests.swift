import XCTest

/// XCUITests for S3 integration: edit/add flows reachable from StartDetailScreen.
/// Requires a real device with a test start that has an existing course
/// (use a dedicated test race with known mark names).
///
/// Launch arguments:
///   "-UITestStartDetail" "1"          — navigate directly to StartDetailScreen with a test start
///   "-UITestStartId" "<start-id>"     — the start ID to load
final class CourseItemIntegrationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launchWithTestStart() {
        app.launchArguments = [
            "-UITestStartDetail", "1",
            "-UITestStartId", ProcessInfo.processInfo.environment["NAVIARI_TEST_START_ID"] ?? "test-start"
        ]
        app.launch()
    }

    // MARK: - Tests

    func testIntegration_editButtonExistsOnMarkRow() {
        launchWithTestStart()
        // Expand the first mark row by tapping it, then look for edit button.
        let firstMark = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'course_row_'")).firstMatch
        if firstMark.waitForExistence(timeout: 10) {
            firstMark.tap()
        }
        XCTAssertTrue(app.buttons["course_edit_button"].waitForExistence(timeout: 5),
                      "At least one course_edit_button should exist in the timeline")
    }

    func testIntegration_editButtonExistsOnStartLineRow() {
        launchWithTestStart()
        // Start line row should expand and show edit button.
        let startRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start'")).firstMatch
        if startRow.waitForExistence(timeout: 10) {
            startRow.tap()
        }
        XCTAssertTrue(app.buttons["course_edit_button"].waitForExistence(timeout: 5))
    }

    func testIntegration_editButtonExistsOnFinishLineRow() {
        launchWithTestStart()
        let finishRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Finish'")).firstMatch
        if finishRow.waitForExistence(timeout: 10) {
            finishRow.tap()
        }
        XCTAssertTrue(app.buttons["course_edit_button"].waitForExistence(timeout: 5))
    }

    func testIntegration_editSheetOpensOnEditTap() {
        launchWithTestStart()
        let firstEditButton = app.buttons["course_edit_button"]
        // Expand a row first if needed.
        app.buttons.firstMatch.tap()
        XCTAssertTrue(firstEditButton.waitForExistence(timeout: 5))
        firstEditButton.tap()
        XCTAssertTrue(app.buttons["course_edit_save_button"].waitForExistence(timeout: 5),
                      "Edit sheet should open and contain the save button")
    }

    func testIntegration_editSheetTitleIsEditMarkForMark() {
        launchWithTestStart()
        // Tap first mark's edit button.
        let markEditButton = app.buttons["course_edit_button"]
        app.buttons.firstMatch.tap()
        XCTAssertTrue(markEditButton.waitForExistence(timeout: 5))
        markEditButton.tap()
        let expectedTitle = NSLocalizedString("course_item_edit_mark_title", comment: "")
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
    }

    func testIntegration_editSheetTitleIsEditStartLine() {
        launchWithTestStart()
        // Tap the start line row edit button.
        let startRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start'")).firstMatch
        XCTAssertTrue(startRow.waitForExistence(timeout: 10))
        startRow.tap()
        app.buttons["course_edit_button"].tap()
        let expectedTitle = NSLocalizedString("course_item_edit_start_line_title", comment: "")
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
    }

    func testIntegration_editSheetTitleIsEditFinishLine() {
        launchWithTestStart()
        let finishRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Finish'")).firstMatch
        XCTAssertTrue(finishRow.waitForExistence(timeout: 10))
        finishRow.tap()
        app.buttons["course_edit_button"].tap()
        let expectedTitle = NSLocalizedString("course_item_edit_finish_line_title", comment: "")
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
    }

    func testIntegration_addMarkButtonOpensAddSheet() {
        launchWithTestStart()
        // Expand a mark row — the add button appears below.
        app.buttons.firstMatch.tap()
        let addButton = app.buttons[NSLocalizedString("course_add_mark_button", comment: "")]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        let expectedTitle = NSLocalizedString("course_item_add_mark_title", comment: "")
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
    }

    func testIntegration_addMarkButtonOnStartLineOpensAddSheet() {
        launchWithTestStart()
        let startRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start'")) .firstMatch
        XCTAssertTrue(startRow.waitForExistence(timeout: 10))
        startRow.tap()

        let addButton = app.buttons[NSLocalizedString("course_add_mark_button", comment: "")]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let expectedTitle = NSLocalizedString("course_item_add_mark_title", comment: "")
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 5))
    }

    func testIntegration_saveClosesSheet() {
        launchWithTestStart()
        app.buttons.firstMatch.tap()
        let editButton = app.buttons["course_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        // After save, the sheet dismisses — save button should disappear.
        XCTAssertFalse(saveButton.waitForExistence(timeout: 5))
    }

    func testIntegration_editMarkSaveUpdatesMarkNameInTimeline() {
        launchWithTestStart()
        app.buttons.firstMatch.tap()
        let editButton = app.buttons["course_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        // Change name to a unique test value.
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearText()
        nameField.typeText("TestEditMark_UNIQUE")
        app.buttons["course_edit_save_button"].tap()
        // After reload, the mark name should appear in the timeline.
        XCTAssertTrue(app.staticTexts["TestEditMark_UNIQUE"].waitForExistence(timeout: 10))
    }

    func testIntegration_addMarkInsertsRowInTimeline() {
        launchWithTestStart()
        // Count existing mark rows (approximate via edit buttons).
        app.buttons.firstMatch.tap()
        let rowCountBefore = app.buttons.matching(identifier: "course_edit_button").count
        // Open add sheet.
        let addButton = app.buttons[NSLocalizedString("course_add_mark_button", comment: "")]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        // Fill name and save.
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText("NewTestMark")
        app.buttons["course_edit_save_button"].tap()
        // Wait for sheet to dismiss and course to reload.
        _ = app.staticTexts["NewTestMark"].waitForExistence(timeout: 10)
        app.buttons.firstMatch.tap()
        let rowCountAfter = app.buttons.matching(identifier: "course_edit_button").count
        XCTAssertGreaterThan(rowCountAfter, rowCountBefore, "Row count should increase after adding a mark")
    }

    func testIntegration_removeMarkRemovesRowFromTimeline() {
        launchWithTestStart()
        app.buttons.firstMatch.tap()
        let rowCountBefore = app.buttons.matching(identifier: "course_edit_button").count
        let editButton = app.buttons["course_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        // Tap remove.
        let removeButton = app.buttons["course_edit_remove_button"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()
        // Confirm removal.
        let confirmButton = app.buttons[NSLocalizedString("course_edit_remove_confirm_action", comment: "")]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()
        // Wait for reload.
        sleep(3)
        app.buttons.firstMatch.tap()
        let rowCountAfter = app.buttons.matching(identifier: "course_edit_button").count
        XCTAssertLessThan(rowCountAfter, rowCountBefore, "Row count should decrease after removing a mark")
    }

    func testIntegration_courseReloadsAfterSave() {
        launchWithTestStart()
        app.buttons.firstMatch.tap()
        app.buttons["course_edit_button"].tap()
        app.buttons["course_edit_save_button"].tap()
        // After save and reload, the timeline should still have items.
        let timelineItem = app.buttons["course_edit_button"]
        XCTAssertTrue(timelineItem.waitForExistence(timeout: 10),
                      "Course timeline should still be non-empty after save")
    }

    func testIntegration_addAfterButtonAbsentOnFinishLine() {
        launchWithTestStart()
        let finishRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Finish'")).firstMatch
        XCTAssertTrue(finishRow.waitForExistence(timeout: 10))
        finishRow.tap()
        let addButton = app.buttons[NSLocalizedString("course_add_mark_button", comment: "")]
        XCTAssertFalse(addButton.exists, "Add mark button should not appear on the finish line row")
    }

    func testIntegration_saveErrorBannerShownIfNetworkFails() {
        app.launchArguments = [
            "-UITestStartDetail", "1",
            "-UITestStartId", "test-start",
            "-UITestSimulateSaveError", "1"
        ]
        app.launch()
        app.buttons.firstMatch.tap()
        app.buttons["course_edit_button"].tap()
        app.buttons["course_edit_save_button"].tap()
        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
        // Sheet should not have dismissed.
        XCTAssertTrue(app.buttons["course_edit_save_button"].exists)
    }
}
