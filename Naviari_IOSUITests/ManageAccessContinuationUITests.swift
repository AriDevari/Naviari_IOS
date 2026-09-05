import XCTest

final class ManageAccessContinuationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testRaceManageCode_startScopedLoginShowsScopeErrorAndPersistsNothing() {
        launch(scenario: "race-course", scope: "start", scopeId: "uitest-detail-start-a")
        openRaceTemplatePicker()
        enterManageCode()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(errorLabel.label, "This code cannot manage this race.")
        XCTAssertEqual(raceManageLoginCount.label, "1")
        XCTAssertEqual(raceCopyRequestCount.label, "0")
        XCTAssertEqual(manageStorageCount.label, "0")
    }

    func testRaceManageCode_participateRoleShowsRoleErrorAndPersistsNothing() {
        launch(scenario: "race-course", scope: "race", scopeId: "uitest-race-detail", role: "participate")
        openRaceTemplatePicker()
        enterManageCode()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertEqual(errorLabel.label, "This code is not a management code.")
        XCTAssertEqual(raceManageLoginCount.label, "1")
        XCTAssertEqual(raceCopyRequestCount.label, "0")
        XCTAssertEqual(manageStorageCount.label, "0")
    }

    func testRaceManageCode_raceScopedLoginResumesPendingRaceBuoyAction() {
        launch(scenario: "race-buoy", scope: "race", scopeId: "uitest-race-detail")

        let addBuoyButton = app.buttons["race_buoy_add_button"]
        // The production Race Detail view places buoy management below the
        // loaded race and course sections. Reveal the real control before
        // exercising its typed management-code continuation.
        app.swipeUp()
        XCTAssertTrue(addBuoyButton.waitForExistence(timeout: 10))
        addBuoyButton.tap()
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["buoy_edit_name_field"].waitForExistence(timeout: 5))
        XCTAssertEqual(manageStorageCount.label, "1")
    }

    func testStartManageCode_startScopedLoginResumesPendingStartCourseSetWithoutConfirmation() {
        launch(scenario: "start-no-course", scope: "start", scopeId: "uitest-start-detail-start")

        let templatePicker = app.buttons["start_detail_course_template_picker_button"]
        XCTAssertTrue(templatePicker.waitForExistence(timeout: 10))
        templatePicker.tap()
        app.buttons["start_detail_course_template_option_uitest-start-detail-template-a"].tap()
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertEqual(startManageLoginCount.label, "1")
        XCTAssertEqual(startCopyRequestCount.label, "1")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertEqual(manageStorageCount.label, "1")
    }

    func testStartManageCode_raceScopedLoginResumesPendingStartCourseChangeWithConfirmation() {
        launch(scenario: "start-existing-course", scope: "race", scopeId: "uitest-race-detail")

        let changeButton = app.buttons["start_detail_course_change_button"]
        XCTAssertTrue(changeButton.waitForExistence(timeout: 10))
        changeButton.tap()
        app.buttons["start_detail_course_template_option_uitest-start-detail-template-a"].tap()
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Change course for this start?"].waitForExistence(timeout: 5))
        XCTAssertEqual(startCopyRequestCount.label, "0")
        XCTAssertEqual(manageStorageCount.label, "1")
    }

    func testSetStartTimeManageCode_seriesScopedLoginDismissesModalAndEnablesProtectedAction() {
        launch(scenario: "set-start-time", scope: "series", scopeId: "uitest-series-continuation")
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertEqual(manageContinuationState.label, "authorized")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "set_start_time_screen").firstMatch.exists)
        XCTAssertEqual(manageStorageCount.label, "1")
    }

    func testSetPositionManageCode_raceScopedLoginDismissesModalAndEnablesProtectedAction() {
        launch(scenario: "set-position", scope: "race", scopeId: "uitest-race-detail")
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertEqual(manageContinuationState.label, "authorized")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "set_position_screen").firstMatch.exists)
        XCTAssertEqual(manageStorageCount.label, "1")
    }

    func testParticipateCodeEntry_keepsStringTokenContract() {
        launch(scenario: "participate")
        enterManageCode()

        XCTAssertFalse(codeEntryModal.waitForExistence(timeout: 5))
        XCTAssertEqual(participationContinuationState.label, "string-token-received")
    }

    private func launch(scenario: String, scope: String? = nil, scopeId: String? = nil, role: String = "manage") {
        var arguments = [
            "-UITestManageAccessContinuation", scenario,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if let scope {
            arguments += ["-UITestManageLoginScope", scope]
        }
        if let scopeId {
            arguments += ["-UITestManageLoginScopeId", scopeId]
        }
        arguments += ["-UITestManageLoginRole", role]
        app.launchArguments = arguments
        app.launch()
    }

    private func openRaceTemplatePicker() {
        let templatePicker = app.buttons["race_course_template_picker_button"]
        XCTAssertTrue(templatePicker.waitForExistence(timeout: 10))
        templatePicker.tap()
        let template = app.buttons["race_course_template_button_uitest-detail-tpl-1"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
    }

    private func enterManageCode() {
        XCTAssertTrue(prefixField.waitForExistence(timeout: 10))
        prefixField.tap()
        prefixField.typeText("MANA")
        suffixField.tap()
        suffixField.typeText("1234")
        verifyButton.tap()
    }

    private var codeEntryModal: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_modal").firstMatch
    }

    private var prefixField: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_prefix_field").firstMatch
    }

    private var suffixField: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_suffix_field").firstMatch
    }

    private var verifyButton: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_verify_button").firstMatch
    }

    private var errorLabel: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_error_label").firstMatch
    }

    private var raceManageLoginCount: XCUIElement {
        app.staticTexts["race_detail_course_manage_login_count"]
    }

    private var raceCopyRequestCount: XCUIElement {
        app.staticTexts["race_detail_course_copy_request_count"]
    }

    private var startManageLoginCount: XCUIElement {
        app.staticTexts["start_detail_manage_login_count"]
    }

    private var startCopyRequestCount: XCUIElement {
        app.staticTexts["start_detail_course_copy_request_count"]
    }

    private var manageStorageCount: XCUIElement {
        app.staticTexts["manage_access_storage_count"]
    }

    private var manageContinuationState: XCUIElement {
        app.staticTexts["manage_access_continuation_state"]
    }

    private var participationContinuationState: XCUIElement {
        app.staticTexts["participation_code_entry_result"]
    }
}
