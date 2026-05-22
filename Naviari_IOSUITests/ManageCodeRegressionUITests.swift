import XCTest

final class ManageCodeRegressionUITests: XCTestCase {

    private enum Screen: String {
        case startDetail
        case startDetailSetStartTime
        case setPosition
        case setStartTime
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testStartDetail_codeModal_prefixAndSuffixFieldsExist() {
        launch(.startDetail)
        openStartDetailModal()

        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
        XCTAssertTrue(suffixField.waitForExistence(timeout: 5))
    }

    func testStartDetail_codeModal_verifyButtonDisabledWhenEmpty() {
        launch(.startDetail)
        openStartDetailModal()

        XCTAssertFalse(verifyButton.isEnabled)
    }

    func testStartDetail_codeModal_verifyButtonEnabledWhenBothFieldsFilled() {
        launch(.startDetail)
        openStartDetailModal()
        enterCode(prefix: "ABCD", suffix: "1234")

        XCTAssertTrue(verifyButton.isEnabled)
    }

    func testStartDetail_codeModal_cancelDismissesSheet() {
        launch(.startDetail)
        openStartDetailModal()

        cancelButton.tap()

        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
    }

    func testStartDetail_codeModal_invalidCode_errorLabelVisible() {
        launch(.startDetail, rejectInvalidCode: true)
        openStartDetailModal()
        enterCode(prefix: "BAD", suffix: "000")

        verifyButton.tap()

        assertErrorLabelShowsText()
    }

    func testSetPosition_codeModal_prefixAndSuffixFieldsExist() {
        launch(.setPosition)
        waitForAutoPresentedModal()

        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
        XCTAssertTrue(suffixField.waitForExistence(timeout: 5))
    }

    func testSetPosition_codeModal_cancelDismissesSheet() {
        launch(.setPosition)
        waitForAutoPresentedModal()

        cancelButton.tap()

        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
    }

    func testSetStartTime_codeModal_prefixAndSuffixFieldsExist() {
        launch(.setStartTime)
        waitForAutoPresentedModal()

        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
        XCTAssertTrue(suffixField.waitForExistence(timeout: 5))
    }

    func testSetStartTime_codeModal_cancelDismissesSheet() {
        launch(.setStartTime)
        waitForAutoPresentedModal()

        cancelButton.tap()

        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
    }

    func testStartDetail_setStartTimeCancelKeepsUserOnStartDetail() {
        launch(.startDetailSetStartTime)

        XCTAssertTrue(startDetailSetStartTimeButton.waitForExistence(timeout: 5))
        startDetailSetStartTimeButton.tap()
        assertCodeEntryModalVisible()

        cancelButton.tap()

        XCTAssertTrue(startDetailScreen.waitForExistence(timeout: 2))
        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
        XCTAssertFalse(startDetailNavigationResult.exists)
    }

    private func launch(_ screen: Screen, rejectInvalidCode: Bool = false) {
        var launchArguments = [
            "-UITestCodeEntryScreen", screen.rawValue
        ]
        if rejectInvalidCode {
            launchArguments += ["-UITestCodeEntryRejectInvalid", "1"]
        }
        app.launchArguments = launchArguments
        app.launch()
    }

    private func openStartDetailModal() {
        let openButton = app.buttons["course_test_open_edit_button"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        openButton.tap()
        assertCodeEntryModalVisible()
    }

    private func waitForAutoPresentedModal() {
        assertCodeEntryModalVisible()
    }

    private func assertCodeEntryModalVisible(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard prefixField.waitForExistence(timeout: 5) else {
            XCTFail("Code entry prefix field not found.\n\(app.debugDescription)", file: file, line: line)
            return
        }
    }

    private func enterCode(prefix: String, suffix: String) {
        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
        prefixField.tap()
        prefixField.typeText(prefix)

        XCTAssertTrue(suffixField.waitForExistence(timeout: 5))
        suffixField.tap()
        suffixField.typeText(suffix)
    }

    private func assertErrorLabelShowsText() {
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 5))
        let predicate = NSPredicate { evaluated, _ in
            guard let element = evaluated as? XCUIElement else { return false }
            return !element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: errorLabel)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
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

    private var startDetailSetStartTimeButton: XCUIElement {
        app.buttons["start_detail_set_start_time_button"]
    }

    private var startDetailScreen: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "start_detail_screen").firstMatch
    }

    private var startDetailNavigationResult: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "start_detail_navigation_result").firstMatch
    }
}