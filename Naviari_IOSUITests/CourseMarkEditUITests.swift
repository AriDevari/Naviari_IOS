import XCTest

/// XCUITests for CourseMarkEditView (S1).
/// These tests require a real device and the app to be launched in a state where
/// CourseMarkEditView is accessible (e.g. via a UI-test launch argument that navigates
/// directly to the edit form with a mock mark pre-loaded).
///
/// Launch argument used: "-UITestCourseMarkEdit" with value "editMark" or "addMark".
final class CourseMarkEditUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helper

    private func launchInEditMode(
        markName: String = "Alpha",
        status: String = "preliminary",
        rounding: String = "port",
        injectedLocation: (lat: Double, lon: Double)? = nil
    ) {
        var launchArguments = [
            "-UITestCourseMarkEdit", "editMark",
            "-UITestMarkName", markName,
            "-UITestMarkStatus", status,
            "-UITestMarkRounding", rounding,
            "-UITestMarkLat", "60.12",
            "-UITestMarkLon", "24.95"
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

    private func launchInAddMode() {
        app.launchArguments = [
            "-UITestCourseMarkEdit", "addMark"
        ]
        app.launch()
    }

    // MARK: - Tests

    func testMarkEditView_saveButtonExists() {
        launchInEditMode()
        XCTAssertTrue(app.buttons["course_edit_save_button"].waitForExistence(timeout: 5))
    }

    func testMarkEditView_formPreFillsNameFromExistingMark() {
        launchInEditMode(markName: "Alpha")
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "Alpha")
    }

    func testMarkEditView_formPreFillsLatDegreesFromExistingMark() {
        launchInEditMode()
        // Lat degrees field is the first text field inside the mark_dms_lat container.
        let dmsLat = app.otherElements["mark_dms_lat"]
        XCTAssertTrue(dmsLat.waitForExistence(timeout: 5))
        let degField = dmsLat.textFields.firstMatch
        XCTAssertTrue(degField.exists)
        // 60.12 → degrees = 60
        XCTAssertEqual(degField.value as? String, "60")
    }

    func testMarkEditView_formPreFillsStatusFinalWhenMarkIsFinal() {
        launchInEditMode(status: "final")
        let finalButton = app.buttons["Final"]
        XCTAssertTrue(finalButton.waitForExistence(timeout: 5))
        XCTAssertTrue(finalButton.isSelected)
    }

    func testMarkEditView_formPreFillsRoundingStarboardWhenMarkIsStarboard() {
        launchInEditMode(rounding: "starboard")
        let starboardButton = app.buttons["Starboard"]
        XCTAssertTrue(starboardButton.waitForExistence(timeout: 5))
        XCTAssertTrue(starboardButton.isSelected)
    }

    func testMarkEditView_saveButtonDisabledWhenNameIsEmpty() {
        launchInEditMode(markName: "Alpha")
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearText()
        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when name is empty")
    }

    func testMarkEditView_statusSegmentSwitchesToFinal() {
        launchInEditMode(status: "preliminary")
        let finalButton = app.buttons["Final"]
        XCTAssertTrue(finalButton.waitForExistence(timeout: 5))
        finalButton.tap()
        XCTAssertTrue(finalButton.isSelected)
        let prelimButton = app.buttons["Preliminary"]
        XCTAssertFalse(prelimButton.isSelected)
    }

    func testMarkEditView_roundingSegmentSwitchesToPort() {
        launchInEditMode(rounding: "starboard")
        let portButton = app.buttons["Port"]
        XCTAssertTrue(portButton.waitForExistence(timeout: 5))
        portButton.tap()
        XCTAssertTrue(portButton.isSelected)
        let starboardButton = app.buttons["Starboard"]
        XCTAssertFalse(starboardButton.isSelected)
    }

    func testMarkEditView_removeButtonExistsInEditMode() {
        launchInEditMode()
        XCTAssertTrue(app.buttons["course_edit_remove_button"].waitForExistence(timeout: 5))
    }

    func testMarkEditView_removeButtonAbsentInAddMode() {
        launchInAddMode()
        // Give the view time to load, then confirm remove button is absent.
        _ = app.buttons["course_edit_save_button"].waitForExistence(timeout: 5)
        XCTAssertFalse(app.buttons["course_edit_remove_button"].exists)
    }

    func testMarkEditView_removeConfirmationAppearsOnTap() {
        launchInEditMode()
        let removeButton = app.buttons["course_edit_remove_button"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()
        // Alert should appear — check for the confirm action button
        let confirmButton = app.buttons[NSLocalizedString("course_edit_remove_confirm_action", comment: "")]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
    }

    func testMarkEditView_removeConfirmCancelKeepsViewOpen() {
        launchInEditMode()
        let removeButton = app.buttons["course_edit_remove_button"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()
        app.buttons["Cancel"].tap()
        // Save button should still exist (view is open)
        XCTAssertTrue(app.buttons["course_edit_save_button"].exists)
    }

    func testMarkEditView_latDMSFieldExists() {
        launchInEditMode()
        XCTAssertTrue(app.otherElements["mark_dms_lat"].waitForExistence(timeout: 5))
    }

    func testMarkEditView_lonDMSFieldExists() {
        launchInEditMode()
        XCTAssertTrue(app.otherElements["mark_dms_lon"].waitForExistence(timeout: 5))
    }

    func testMarkEditView_dmsDegreesFieldRejectsAlpha() {
        launchInEditMode()
        let dmsLat = app.otherElements["mark_dms_lat"]
        XCTAssertTrue(dmsLat.waitForExistence(timeout: 5))
        let degField = dmsLat.textFields.firstMatch
        degField.tap()
        degField.clearText()
        degField.typeText("ab3c")
        // Only "3" should remain (alpha stripped).
        XCTAssertEqual(degField.value as? String, "3")
    }

    func testMarkEditView_keyboardDoneButtonDismissesKeyboard() {
        launchInEditMode()
        let nameField = app.textFields.matching(identifier: "course_edit_name_field").firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        XCTAssertTrue(app.keyboards.count > 0, "Keyboard should be visible after tapping name field")
        app.toolbars.buttons["Done"].tap()
        XCTAssertEqual(app.keyboards.count, 0, "Keyboard should be dismissed after tapping Done")
    }

    func testMarkEditView_formScrollsFieldAboveKeyboard() {
        launchInEditMode()
        let dmsLon = app.otherElements["mark_dms_lon"]
        XCTAssertTrue(dmsLon.waitForExistence(timeout: 5))
        // Tap the lon hemisphere toggle (last interactive element in DMS lon field).
        let lonToggle = dmsLon.buttons.lastMatch
        lonToggle?.tap()
        // The DMS lon container should be within the visible screen area.
        let screenHeight = app.frame.height
        let frameMaxY = dmsLon.frame.maxY
        XCTAssertLessThanOrEqual(frameMaxY, screenHeight,
                                  "The lon DMS container should be fully visible above keyboard")
    }

    func testMarkEditView_gpsButtonPopulatesCoordinateFields() {
        launchInEditMode(injectedLocation: (lat: 61.5, lon: 25.75))

        let gpsButton = app.buttons["course_edit_gps_mark"]
        XCTAssertTrue(gpsButton.waitForExistence(timeout: 5))
        gpsButton.tap()

        let latDegrees = app.otherElements["mark_dms_lat"].textFields.firstMatch
        let lonDegrees = app.otherElements["mark_dms_lon"].textFields.firstMatch
        XCTAssertEqual(latDegrees.value as? String, "61")
        XCTAssertEqual(lonDegrees.value as? String, "25")
    }

    func testMarkEditView_positionDisclosureShowsClipboardActions() {
        launchInEditMode()

        let disclosureButton = app.buttons["course_edit_gps_mark_disclosure"]
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 5))
        disclosureButton.tap()

        XCTAssertTrue(app.buttons["course_edit_copy_to_clipboard_action"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["course_edit_paste_from_clipboard_action"].waitForExistence(timeout: 5))
    }

    func testMarkEditView_invalidCoordinateShowsValidationError() {
        launchInEditMode()

        let latDegrees = app.otherElements["mark_dms_lat"].textFields.firstMatch
        XCTAssertTrue(latDegrees.waitForExistence(timeout: 5))
        latDegrees.tap()
        latDegrees.clearText()
        latDegrees.typeText("91")

        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
    }

    func testMarkEditView_saveErrorBannerShownOnFailure() {
        // Launch with a flag that injects a failing mock network response.
        app.launchArguments = [
            "-UITestCourseMarkEdit", "editMark",
            "-UITestMarkName", "Alpha",
            "-UITestSimulateSaveError", "1"
        ]
        app.launch()
        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
    }

    func testMarkEditView_copyToClipboardShowsInlineSuccessFeedback() {
        launchInEditMode()

        let disclosureButton = app.buttons["course_edit_gps_mark_disclosure"]
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 5))
        disclosureButton.tap()

        let copyAction = app.buttons["course_edit_copy_to_clipboard_action"]
        XCTAssertTrue(copyAction.waitForExistence(timeout: 5))
        copyAction.tap()

        // Valid prefilled coordinate → inline success feedback rendered next to the
        // position buttons (not the bottom save bar).
        let feedback = app.staticTexts["mark_action_feedback_label"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5),
                      "Inline success feedback should appear after a valid copy")
    }

    // MARK: - DDM (Degrees Decimal Minutes) mode

    /// Opens the position action menu and switches the editor into DDM mode.
    private func switchToDDMMode() {
        let disclosureButton = app.buttons["course_edit_gps_mark_disclosure"]
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 5))
        disclosureButton.tap()

        let ddmAction = app.buttons["course_edit_ddm_action"]
        XCTAssertTrue(ddmAction.waitForExistence(timeout: 5))
        ddmAction.tap()
    }

    func testMarkEditView_ddmActionShowsStructuredFieldsPrefilled() {
        launchInEditMode()
        switchToDDMMode()

        // Both structured DDM containers should now be present.
        let ddmLat = app.otherElements["mark_ddm_lat"]
        let ddmLon = app.otherElements["mark_ddm_lon"]
        XCTAssertTrue(ddmLat.waitForExistence(timeout: 5))
        XCTAssertTrue(ddmLon.waitForExistence(timeout: 5))

        // Degrees prefill from the existing mark (60.12 / 24.95).
        XCTAssertEqual(ddmLat.textFields.element(boundBy: 0).value as? String, "60")
        XCTAssertEqual(ddmLon.textFields.element(boundBy: 0).value as? String, "24")

        // Decimal-minutes box prefills too, in leading-zero chartplotter form:
        // 60.12 → 07.2'. Normalise the locale decimal separator before comparing.
        let latMinutesValue = (ddmLat.textFields.element(boundBy: 1).value as? String ?? "")
            .replacingOccurrences(of: ",", with: ".")
        XCTAssertTrue(latMinutesValue.hasPrefix("07.2"),
                      "Latitude decimal-minutes should prefill to ~07.2', got: \(latMinutesValue)")
    }

    func testMarkEditView_ddmEntryResolvesAndRoundTripsToDecimal() {
        launchInEditMode()
        switchToDDMMode()

        // Enter a value via the DDM field's hemisphere control: flip latitude N → S.
        // A button tap is a deterministic interaction (custom numeric text boxes are not
        // reliably clearable in XCUITest), and flipping to S must resolve to a NEGATIVE
        // decimal — proving the DDM field writes to the shared coordinate and round-trips.
        let ddmLat = app.otherElements["mark_ddm_lat"]
        XCTAssertTrue(ddmLat.waitForExistence(timeout: 5))
        let southButton = ddmLat.buttons["S"]
        XCTAssertTrue(southButton.waitForExistence(timeout: 5))
        southButton.tap()

        // Switch to decimal mode; the DDM change must have resolved into the shared
        // coordinate and round-trip to the decimal representation.
        let disclosureButton = app.buttons["course_edit_gps_mark_disclosure"]
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 5))
        disclosureButton.tap()
        let decimalAction = app.buttons["course_edit_decimal_numbers_action"]
        XCTAssertTrue(decimalAction.waitForExistence(timeout: 5))
        decimalAction.tap()

        let decimalLat = app.textFields["mark_decimal_lat"]
        XCTAssertTrue(decimalLat.waitForExistence(timeout: 5))
        // Normalise the locale decimal separator before comparing. 60.12 N → -60.12.
        let decimalValue = (decimalLat.value as? String ?? "").replacingOccurrences(of: ",", with: ".")
        XCTAssertTrue(decimalValue.hasPrefix("-60.1"),
                      "Flipping latitude to S in DDM should resolve to ~-60.12 in decimal, got: \(decimalValue)")
    }

    func testMarkEditView_ddmInvalidLatitudeShowsValidationErrorOnSave() {
        launchInEditMode()
        switchToDDMMode()

        // Set latitude degrees out of range (91) — the .ddm resolve path must reject it.
        let ddmLat = app.otherElements["mark_ddm_lat"]
        XCTAssertTrue(ddmLat.waitForExistence(timeout: 5))
        let latDegrees = ddmLat.textFields.firstMatch
        latDegrees.tap()
        latDegrees.clearText()
        latDegrees.typeText("91")
        if app.toolbars.buttons["Done"].exists {
            app.toolbars.buttons["Done"].tap()
        }

        let saveButton = app.buttons["course_edit_save_button"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        let errorLabel = app.staticTexts["course_edit_save_error_label"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5),
                      "An out-of-range DDM latitude must surface a validation error on save")
    }

    func testMarkEditView_copyToClipboardWithIncompleteCoordinateShowsInlineError() {
        launchInEditMode()

        // Make the coordinate incomplete so the copy action fails to resolve.
        let dmsLat = app.otherElements["mark_dms_lat"]
        XCTAssertTrue(dmsLat.waitForExistence(timeout: 5))
        let degField = dmsLat.textFields.firstMatch
        degField.tap()
        degField.clearText()
        if app.toolbars.buttons["Done"].exists {
            app.toolbars.buttons["Done"].tap()
        }

        let disclosureButton = app.buttons["course_edit_gps_mark_disclosure"]
        XCTAssertTrue(disclosureButton.waitForExistence(timeout: 5))
        disclosureButton.tap()

        let copyAction = app.buttons["course_edit_copy_to_clipboard_action"]
        XCTAssertTrue(copyAction.waitForExistence(timeout: 5))
        copyAction.tap()

        // Action-time failure is surfaced inline, NOT in the bottom save-bar label.
        let feedback = app.staticTexts["mark_action_feedback_label"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5),
                      "Inline error feedback should appear when copying an incomplete coordinate")
        XCTAssertFalse(app.staticTexts["course_edit_save_error_label"].exists,
                       "Action failures must not be routed to the save-bar error label")
    }
}

// MARK: - XCUIElement helpers

extension XCUIElement {
    func clearText() {
        guard let currentValue = value as? String, !currentValue.isEmpty else { return }
        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
    }
}

extension XCUIElementQuery {
    var lastMatch: XCUIElement? {
        let elements = allElementsBoundByIndex
        return elements.last
    }
}
