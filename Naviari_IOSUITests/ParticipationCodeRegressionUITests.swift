import XCTest

final class ParticipationCodeRegressionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testParticipateView_codeModal_prefixAndSuffixFieldsExist() {
        launchParticipate()

        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
        XCTAssertTrue(suffixField.waitForExistence(timeout: 5))
    }

    func testParticipateView_codeModal_verifyButtonDisabledWhenEmpty() {
        launchParticipate()

        XCTAssertFalse(verifyButton.isEnabled)
    }

    func testParticipateView_codeModal_verifyButtonEnabledWhenBothFilled() {
        launchParticipate()
        enterCode(prefix: "PART", suffix: "1234")

        XCTAssertTrue(verifyButton.isEnabled)
    }

    func testParticipateView_codeModal_cancelDismissesSheet() {
        launchParticipate()

        cancelButton.tap()

        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
    }

    func testStartDetail_participateCancelKeepsUserOnStartDetail() {
        launchStartDetailParticipate()

        XCTAssertTrue(participateFromStartDetailButton.waitForExistence(timeout: 5))
        participateFromStartDetailButton.tap()
        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))

        cancelButton.tap()

        XCTAssertTrue(startDetailScreen.waitForExistence(timeout: 2))
        XCTAssertFalse(prefixField.waitForExistence(timeout: 2))
        XCTAssertFalse(startDetailNavigationResult.exists)
    }

    func testParticipateView_codeModal_invalidCode_errorLabelVisible() {
        launchParticipate(rejectInvalidCode: true)
        enterCode(prefix: "BAD", suffix: "999")

        verifyButton.tap()

        assertErrorLabelShowsText()
    }

    private func launchParticipate(rejectInvalidCode: Bool = false) {
        var launchArguments = [
            "-UITestCodeEntryScreen", "participate"
        ]
        if rejectInvalidCode {
            launchArguments += ["-UITestCodeEntryRejectInvalid", "1"]
        }
        app.launchArguments = launchArguments
        app.launch()

        XCTAssertTrue(prefixField.waitForExistence(timeout: 5))
    }

    private func launchStartDetailParticipate() {
        app.launchArguments = [
            "-UITestCodeEntryScreen", "startDetailParticipate"
        ]
        app.launch()
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

    private var participateFromStartDetailButton: XCUIElement {
        app.buttons["start_detail_participate_button"]
    }

    private var startDetailScreen: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "start_detail_screen").firstMatch
    }

    private var startDetailNavigationResult: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "start_detail_navigation_result").firstMatch
    }
}