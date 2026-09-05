import XCTest

final class StartDetailCourseManagementUITests: XCTestCase {

    private enum Scenario: String {
        case noCourseCachedStartToken
        case noCourseRaceTokenAfterCodeEntry
        case existingCourseCachedRaceToken
        case invalidScopeRaceToken
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testStartNoCourseEligibleToken_SelectingTemplatePerformsCopyOnceWithoutConfirmation() {
        launch(.noCourseCachedStartToken)

        XCTAssertTrue(templatePickerButton.waitForExistence(timeout: 10))
        templatePickerButton.tap()

        let template = templateOption(id: "uitest-start-management-template-alpha")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(waitForLabel(refreshRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(courseDetail("Replacement Start Line").waitForExistence(timeout: 10))
        XCTAssertFalse(confirmationAlert.exists)
        XCTAssertFalse(codeEntryModal.exists)
        attachScreenshot(named: "start-no-course-direct-set")
    }

    func testStartNoCourseEligibleRaceTokenAfterCodeEntry_PerformsCopyOnceWithoutConfirmation() {
        launch(.noCourseRaceTokenAfterCodeEntry)

        XCTAssertTrue(templatePickerButton.waitForExistence(timeout: 10))
        templatePickerButton.tap()

        let template = templateOption(id: "uitest-start-management-template-alpha")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 8))
        enterManageCodeAndVerify()

        XCTAssertTrue(waitForLabel(manageLoginCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(waitForLabel(refreshRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(courseDetail("Replacement Start Line").waitForExistence(timeout: 10))
        XCTAssertFalse(confirmationAlert.exists)
        XCTAssertFalse(codeEntryModal.exists)
    }

    func testStartExistingCourseEligibleToken_SelectingTemplateShowsConfirmationBeforeCopy() {
        launch(.existingCourseCachedRaceToken)

        XCTAssertTrue(changeCourseButton.waitForExistence(timeout: 10))
        XCTAssertTrue(courseDetail("Assigned Start Line").waitForExistence(timeout: 10))

        changeCourseButton.tap()

        let template = templateOption(id: "uitest-start-management-template-replacement")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 8))
        XCTAssertEqual(copyRequestCountLabel.label, "0")
        attachScreenshot(named: "start-existing-course-confirmation")
    }

    func testStartExistingCourseCancel_PreservesCurrentCourseAndMakesNoCopyRequest() {
        launch(.existingCourseCachedRaceToken)

        XCTAssertTrue(changeCourseButton.waitForExistence(timeout: 10))
        XCTAssertTrue(courseDetail("Assigned Start Line").waitForExistence(timeout: 10))

        changeCourseButton.tap()

        let template = templateOption(id: "uitest-start-management-template-replacement")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 8))
        cancelConfirmationButton.tap()

        XCTAssertFalse(confirmationAlert.exists)
        XCTAssertTrue(courseDetail("Assigned Start Line").waitForExistence(timeout: 5))
        XCTAssertFalse(courseDetail("Replacement Start Line").exists)
        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "0", timeout: 5))
        attachScreenshot(named: "start-existing-course-cancel")
    }

    func testStartExistingCourseConfirm_CopiesOnceAndRefreshesTimeline() {
        launch(.existingCourseCachedRaceToken)

        XCTAssertTrue(changeCourseButton.waitForExistence(timeout: 10))
        XCTAssertTrue(courseDetail("Assigned Start Line").waitForExistence(timeout: 10))

        changeCourseButton.tap()

        let template = templateOption(id: "uitest-start-management-template-replacement")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 8))
        confirmChangeButton.tap()

        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(waitForLabel(refreshRequestCountLabel, toEqual: "1", timeout: 10))
        XCTAssertTrue(courseDetail("Replacement Start Line").waitForExistence(timeout: 10))
        XCTAssertFalse(courseDetail("Assigned Start Line").exists)
        attachScreenshot(named: "start-existing-course-confirmed")
    }

    func testStartCourseInvalidScope_RemainsInCodeEntryAndPersistsNothing() {
        launch(.invalidScopeRaceToken)

        XCTAssertTrue(templatePickerButton.waitForExistence(timeout: 10))
        templatePickerButton.tap()

        let template = templateOption(id: "uitest-start-management-template-alpha")
        XCTAssertTrue(template.waitForExistence(timeout: 8))
        template.tap()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 8))
        enterManageCodeAndVerify()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 8))
        assertNonEmptyLabel(errorLabel)
        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "0", timeout: 5))
        XCTAssertTrue(waitForLabel(refreshRequestCountLabel, toEqual: "0", timeout: 5))
        XCTAssertTrue(waitForLabel(manageAccessStorageCountLabel, toEqual: "0", timeout: 5))

        cancelButton.tap()
        XCTAssertFalse(codeEntryModal.exists)

        templatePickerButton.tap()
        let sameTemplate = templateOption(id: "uitest-start-management-template-alpha")
        XCTAssertTrue(sameTemplate.waitForExistence(timeout: 8))
        sameTemplate.tap()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 8))
        XCTAssertTrue(waitForLabel(copyRequestCountLabel, toEqual: "0", timeout: 5))
        attachScreenshot(named: "start-invalid-scope-modal-retention")
    }

    private func launch(_ scenario: Scenario) {
        app.launchArguments = [
            "-UITestStartDetailCourseManagementScenario", scenario.rawValue,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
    }

    private func templateOption(id: String) -> XCUIElement {
        app.buttons["start_detail_course_template_option_\(id)"]
    }

    private func courseDetail(_ label: String) -> XCUIElement {
        app.staticTexts[label]
    }

    private func enterManageCodeAndVerify() {
        XCTAssertTrue(prefixField.waitForExistence(timeout: 8))
        prefixField.tap()
        prefixField.typeText("MANA")

        XCTAssertTrue(suffixField.waitForExistence(timeout: 8))
        suffixField.tap()
        suffixField.typeText("1234")

        XCTAssertTrue(verifyButton.waitForExistence(timeout: 8))
        verifyButton.tap()
    }

    private func assertNonEmptyLabel(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        let predicate = NSPredicate { evaluated, _ in
            guard let value = evaluated as? XCUIElement else { return false }
            return !value.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 8), .completed)
    }

    private func waitForLabel(_ element: XCUIElement, toEqual value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var templatePickerButton: XCUIElement {
        app.buttons["start_detail_course_template_picker_button"]
    }

    private var changeCourseButton: XCUIElement {
        app.buttons["start_detail_course_change_button"]
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

    private var cancelButton: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_cancel_button").firstMatch
    }

    private var errorLabel: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "code_entry_error_label").firstMatch
    }

    private var copyRequestCountLabel: XCUIElement {
        app.staticTexts["start_detail_course_copy_request_count"]
    }

    private var manageLoginCountLabel: XCUIElement {
        app.staticTexts["start_detail_manage_login_count"]
    }

    private var refreshRequestCountLabel: XCUIElement {
        app.staticTexts["start_detail_course_refresh_request_count"]
    }

    private var manageAccessStorageCountLabel: XCUIElement {
        app.staticTexts["manage_access_storage_count"]
    }

    private var confirmationAlert: XCUIElement {
        app.alerts.firstMatch
    }

    private var cancelConfirmationButton: XCUIElement {
        confirmationAlert.buttons["Cancel"]
    }

    private var confirmChangeButton: XCUIElement {
        confirmationAlert.buttons["Change course"]
    }
}