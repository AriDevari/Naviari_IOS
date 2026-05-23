import XCTest

/// XCUITests for `RaceCourseSectionView` (S2 of ios-race-level-course-selection).
///
/// Each test launches the app with `-UITestRaceCourseSectionState <scenario>`,
/// which routes `ContentView` into a debug-only host
/// (`RaceCourseSectionUITestHarnessView`) showing the section in the requested
/// visual branch. Production launches never route here because the flag is
/// absent.
///
/// Scenarios:
///   "A"          — State A with three templates available
///   "A_loading"  — State A while templates are loading (no templates yet)
///   "A_copy"     — State A while a shared-course copy is in flight
///   "A_empty"    — State A with zero templates available
///   "B"          — State B (mixed courses)
///   "C"          — State C (all starts share the same course)
///   "loading"    — Top-level `.loading` (no section header)
///   "error"      — Top-level `.error(...)` with retry button
final class RaceCourseSectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launch(scenario: String) {
        app.launchArguments = [
            "-UITestRaceCourseSectionState", scenario
        ]
        app.launch()
    }

    private var templatePickerButton: XCUIElement {
        app.buttons["race_course_template_picker_button"]
    }

    /// Returns the first template option identifier used by the section view.
    /// Template options are identified as `race_course_template_button_<id>`;
    /// fixtures use ids `uitest-tpl-1`, `uitest-tpl-2`, `uitest-tpl-3`.
    private func templateButton(at index: Int = 1) -> XCUIElement {
        app.buttons["race_course_template_button_uitest-tpl-\(index)"]
    }

    // MARK: - State A — Picker button visible

    func testRaceCourseSectionView_stateA_pickerButtonVisible() {
        launch(scenario: "A")
        let picker = templatePickerButton
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "Expected the race course template picker button to exist in State A"
        )
        XCTAssertTrue(picker.isHittable, "Template picker button should be hittable in State A")
    }

    func testRaceCourseSectionView_stateA_pickerRevealsTemplateOptions() {
        launch(scenario: "A")
        let picker = templatePickerButton
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()

        let firstTemplate = templateButton(at: 1)
        XCTAssertTrue(
            firstTemplate.waitForExistence(timeout: 5),
            "Expected a template option to be visible after expanding the picker"
        )
    }

    // MARK: - State A — Loading hides templates

    func testRaceCourseSectionView_stateA_loadingHidesTemplates() {
        launch(scenario: "A_loading")
        let loading = app.activityIndicators["race_course_loading"]
        let progressOther = app.otherElements["race_course_loading"]
        let loadingExists = loading.waitForExistence(timeout: 5)
            || progressOther.waitForExistence(timeout: 1)
        XCTAssertTrue(
            loadingExists,
            "Loading indicator (race_course_loading) should be visible while templates load"
        )
        let anyTemplateButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'race_course_template_button_'")
        ).firstMatch
        XCTAssertFalse(
            anyTemplateButton.exists,
            "No template options should exist while templates are loading"
        )
    }

    // MARK: - State A — Copy in flight disables picker

    func testRaceCourseSectionView_stateA_copyLoadingDisablesPicker() {
        launch(scenario: "A_copy")
        let picker = templatePickerButton
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "Template picker button should still exist while a copy is in flight"
        )
        XCTAssertFalse(
            picker.isEnabled,
            "Template picker button must be disabled while a shared-course copy is in flight"
        )
    }

    // MARK: - State B — Mixed label visible

    func testRaceCourseSectionView_stateB_mixedLabelVisible() {
        launch(scenario: "B")
        let label = app.staticTexts["race_course_mixed_label"]
        XCTAssertTrue(
            label.waitForExistence(timeout: 5),
            "Mixed-state label (race_course_mixed_label) should be visible in State B"
        )
    }

    // MARK: - State B — Picker not present

    func testRaceCourseSectionView_stateB_pickerNotVisible() {
        launch(scenario: "B")
        // Wait for the mixed label so the harness has finished rendering.
        _ = app.staticTexts["race_course_mixed_label"].waitForExistence(timeout: 5)
        let picker = templatePickerButton
        XCTAssertFalse(
            picker.exists,
            "Template picker button must not be present in State B"
        )
    }

    // MARK: - State C — Course timeline visible

    func testRaceCourseSectionView_stateC_courseTimelineVisible() {
        launch(scenario: "C")
        let timeline = app.otherElements["race_course_timeline"]
        XCTAssertTrue(
            timeline.waitForExistence(timeout: 5),
            "Course timeline container (race_course_timeline) should be visible in State C"
        )
    }

    // MARK: - State C — Mixed label not present

    func testRaceCourseSectionView_stateC_mixedLabelNotVisible() {
        launch(scenario: "C")
        // Wait for the timeline so the harness has finished rendering.
        _ = app.otherElements["race_course_timeline"].waitForExistence(timeout: 5)
        let mixedLabel = app.staticTexts["race_course_mixed_label"]
        XCTAssertFalse(
            mixedLabel.exists,
            "Mixed-state label must not be present in State C"
        )
    }

    // MARK: - Top-level loading state

    func testRaceCourseSectionView_loading_indicatorVisible() {
        launch(scenario: "loading")
        let loading = app.activityIndicators["race_course_loading"]
        let progressOther = app.otherElements["race_course_loading"]
        let loadingExists = loading.waitForExistence(timeout: 5)
            || progressOther.waitForExistence(timeout: 1)
        XCTAssertTrue(
            loadingExists,
            "Top-level loading indicator (race_course_loading) should be visible in the loading state"
        )
    }

    // MARK: - Error state

    func testRaceCourseSectionView_error_retryButtonVisible() {
        launch(scenario: "error")
        let retry = app.buttons["race_course_retry_button"]
        XCTAssertTrue(
            retry.waitForExistence(timeout: 5),
            "Retry button (race_course_retry_button) should be visible in error state"
        )
        XCTAssertTrue(retry.isHittable, "Retry button must be hittable in error state")
    }
}
