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

final class StartDetailCourseReplacementUITests: XCTestCase {

    private struct LocaleExpectation {
        let languageCode: String
        let appleLocale: String
        let buttonTitle: String
        let alertTitle: String
        let alertMessage: String
        let confirmTitle: String
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testStartDetailAssignedCourse_ShowsChangeCourseAction() {
        launchAssignedStartDetail(hasCachedToken: true)

        XCTAssertTrue(changeCourseButton.waitForExistence(timeout: 10))
        XCTAssertTrue(changeCourseButton.isHittable)
        XCTAssertTrue(app.staticTexts["Assigned Start Line"].exists)
        attachScreenshot(named: "assigned-state")
    }

    func testStartDetailChangeCourse_CancelKeepsExistingCourseAndMakesNoCopyRequest() {
        launchAssignedStartDetail(hasCachedToken: true)

        openConfirmationAlert()
        let cancelButton = app.alerts.firstMatch.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        attachScreenshot(named: "confirmation-cancel")
        cancelButton.tap()

        XCTAssertEqual(copyRequestCountLabel.label, "0")
        XCTAssertTrue(app.staticTexts["Assigned Start Line"].exists)
        XCTAssertFalse(app.staticTexts["Replacement Start Line"].exists)
    }

    func testStartDetailChangeCourse_ConfirmationCopiesAndRefreshesTimeline() {
        launchAssignedStartDetail(hasCachedToken: true)

        openConfirmationAlert()
        let confirmButton = app.alerts.firstMatch.buttons["Change course"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        attachScreenshot(named: "confirmation-success")
        confirmButton.tap()

        XCTAssertTrue(app.staticTexts["Replacement Start Line"].waitForExistence(timeout: 10))
        XCTAssertEqual(copyRequestCountLabel.label, "1")
        XCTAssertEqual(refreshRequestCountLabel.label, "1")
        attachScreenshot(named: "replacement-success")
    }

    func testStartDetailChangeCourse_MissingManageTokenUsesCodeEntryBeforeCopy() {
        launchAssignedStartDetail(hasCachedToken: false)

        changeCourseButton.tap()
        XCTAssertTrue(templateOption.waitForExistence(timeout: 8))
        templateOption.tap()

        XCTAssertTrue(codeEntryModal.waitForExistence(timeout: 8))
        XCTAssertEqual(copyRequestCountLabel.label, "0")

        prefixField.tap()
        prefixField.typeText("MANA")
        suffixField.tap()
        suffixField.typeText("1234")
        verifyButton.tap()

        let confirmationAlert = app.alerts["Change course for this start?"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 8))
        XCTAssertEqual(copyRequestCountLabel.label, "0")
        XCTAssertEqual(manageLoginCountLabel.label, "1")
        attachScreenshot(named: "code-entry-resume")
        confirmationAlert.buttons["Change course"].tap()

        XCTAssertTrue(app.staticTexts["Replacement Start Line"].waitForExistence(timeout: 10))
        XCTAssertEqual(copyRequestCountLabel.label, "1")
    }

    func testStartDetailChangeCourse_CopyFailureKeepsExistingCourseAndShowsError() {
        launchAssignedStartDetail(hasCachedToken: true, shouldFailCopy: true)

        openConfirmationAlert()
        app.alerts.firstMatch.buttons["Change course"].tap()

        let expectedError = "Server error (500): UITest synthetic copy failure"
        XCTAssertTrue(app.staticTexts[expectedError].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Assigned Start Line"].exists)
        XCTAssertFalse(app.staticTexts["Replacement Start Line"].exists)
        XCTAssertEqual(copyRequestCountLabel.label, "1")
        attachScreenshot(named: "copy-failure")
    }

    func testStartDetailChangeCourse_AllLocalesResolveNewKeys() {
        let expectations = [
            LocaleExpectation(
                languageCode: "en",
                appleLocale: "en_US",
                buttonTitle: "Change course",
                alertTitle: "Change course for this start?",
                alertMessage: "The selected course will replace the course currently used by this start.",
                confirmTitle: "Change course"
            ),
            LocaleExpectation(
                languageCode: "fi",
                appleLocale: "fi_FI",
                buttonTitle: "Vaihda rata",
                alertTitle: "Vaihdetaanko tämän lähdön rata?",
                alertMessage: "Valittu rata korvaa tämän lähdön tällä hetkellä käyttämän radan.",
                confirmTitle: "Vaihda rata"
            ),
            LocaleExpectation(
                languageCode: "sv",
                appleLocale: "sv_SE",
                buttonTitle: "Byt bana",
                alertTitle: "Byta bana för denna start?",
                alertMessage: "Den valda banan ersätter banan som den här starten använder just nu.",
                confirmTitle: "Byt bana"
            )
        ]

        for expectation in expectations {
            app.terminate()
            launchAssignedStartDetail(hasCachedToken: true, locale: expectation)

            let localizedButton = app.buttons[expectation.buttonTitle]
            XCTAssertTrue(localizedButton.waitForExistence(timeout: 10))
            attachScreenshot(named: "locale-\(expectation.languageCode)-button")
            localizedButton.tap()
            XCTAssertTrue(templateOption.waitForExistence(timeout: 8))
            templateOption.tap()

            let localizedAlert = app.alerts[expectation.alertTitle]
            XCTAssertTrue(localizedAlert.waitForExistence(timeout: 8))
            XCTAssertTrue(localizedAlert.staticTexts[expectation.alertMessage].exists)
            XCTAssertTrue(localizedAlert.buttons[expectation.confirmTitle].exists)
            attachScreenshot(named: "locale-\(expectation.languageCode)-alert")
            localizedAlert.buttons.firstMatch.tap()
        }
    }

    private func launchAssignedStartDetail(
        hasCachedToken: Bool,
        locale: LocaleExpectation? = nil,
        shouldFailCopy: Bool = false
    ) {
        let resolvedLocale = locale ?? LocaleExpectation(
            languageCode: "en",
            appleLocale: "en_US",
            buttonTitle: "Change course",
            alertTitle: "Change course for this start?",
            alertMessage: "The selected course will replace the course currently used by this start.",
            confirmTitle: "Change course"
        )
        var launchArguments = [
            "-UITestStartDetailCourseReplacementScenario", "assigned"
        ]
        if hasCachedToken {
            launchArguments += ["-UITestStartDetailCourseReplacementHasToken", "1"]
        }
        if shouldFailCopy {
            launchArguments += ["-UITestStartDetailCourseReplacementCopyFails", "1"]
        }
        launchArguments += [
            "-AppleLanguages", "(\(resolvedLocale.languageCode))",
            "-AppleLocale", resolvedLocale.appleLocale
        ]
        app.launchArguments = launchArguments
        app.launch()

        XCTAssertTrue(startDetailScreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Assigned Start Line"].waitForExistence(timeout: 10))
    }

    private func openConfirmationAlert() {
        changeCourseButton.tap()
        XCTAssertTrue(templateOption.waitForExistence(timeout: 8))
        attachScreenshot(named: "picker-open")
        templateOption.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var startDetailScreen: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "start_detail_screen").firstMatch
    }

    private var changeCourseButton: XCUIElement {
        app.buttons["start_detail_course_change_button"]
    }

    private var templateOption: XCUIElement {
        app.buttons["start_detail_course_template_option_uitest-start-detail-template-replacement"]
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

    private var copyRequestCountLabel: XCUIElement {
        app.staticTexts["start_detail_course_copy_request_count"]
    }

    private var manageLoginCountLabel: XCUIElement {
        app.staticTexts["start_detail_course_manage_login_count"]
    }

    private var refreshRequestCountLabel: XCUIElement {
        app.staticTexts["start_detail_course_refresh_request_count"]
    }
}
