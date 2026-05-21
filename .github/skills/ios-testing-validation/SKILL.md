---
name: ios-testing-validation
description: "Validate iOS changes in Naviari_IOS. Use when: running narrow xcodebuild checks, planning XCTest or manual verification, validating visually sensitive SwiftUI work, checking reusable-view regressions, or recording slice-level evidence after iOS edits."
user-invocable: true
---

# iOS Testing Validation

Use this skill when validating iOS changes in `Naviari_IOS`.

## Read First

- `AGENTS.md`
- `.github/instructions/ios-native.instructions.md`
- the active feature package validation section when the work is feature-scoped

## Purpose

This skill exists to make iOS validation explicit and cheap:

- build the touched slice narrowly when possible
- validate visible behavior intentionally
- confirm theme-token and reusable-view rules, not only visual appearance

## Use When

- a SwiftUI or UIKit change needs validation
- a feature slice requires manual evidence
- visually sensitive UI work needs screenshot-based checking
- reusable view extraction needs regression checking
- deciding the narrowest build/test command to run

## Do

- prefer the smallest validation that can falsify the current change
- run validation immediately after the first substantive edit
- combine build evidence with targeted manual checks for visible work
- verify theme-token use and reusable-view boundaries when relevant
- record concise evidence in the active slice report when feature-scoped

## Do Not

- rely on diff-only review when a narrow executable check exists
- skip manual verification for visually sensitive changes
- expand scope before validating the current slice
- claim parity or UI completion without direct visual evidence

## Test-First Rule

Before writing any implementation code for a slice:

1. Read the slice acceptance criteria from the task context doc.
2. Translate every acceptance criterion into a named `XCUITest` function. Examples:
   - `testMarkExpandedRendersEditButton` — `app.buttons["course_edit_button"].exists` is true
   - `testAddMarkButtonAbsentOnFinishLine` — `app.buttons["course_add_mark_button"].exists` is false
   - `testCollapsedCardShowsNoStatusChip` — no chip element exists when card is collapsed
3. Add those test stubs to the `Naviari_IOSUITests` target and confirm they **fail** (because nothing is implemented yet). A failing test is the correct starting state.
4. Write the implementation until the tests pass.
5. The slice is not done until every named test is green. Attach the test run output to the slice report.

If an acceptance criterion cannot be expressed as an executable assertion, the criterion is too vague — refine it before starting.

For each test, add an `accessibilityIdentifier` to the SwiftUI element being tested. Use the key string from the localization bundle (e.g. `"course_edit_button"`) as the identifier so it stays consistent.

## Procedure

1. Read the slice acceptance criteria and write all XCUITest stubs before touching implementation code.
2. Run the stubs to confirm they fail.
3. Implement the slice.
4. Run the tests until they all pass.
5. For visible UI work, also perform a targeted simulator or screenshot check.
6. Confirm theme-token use, localization, and reusable-view ownership where relevant.
7. Record the test run output and any screenshots in the slice report.

## Validation Checklist

- all named XCUITest functions pass
- build succeeds for the touched iOS target
- no new hardcoded visual values where `Theme` should own them
- host screen still hosts; reusable view still renders
- one-open / tap / loading / error behavior still works as expected
- visual hierarchy matches the approved slice

## Notes

- Use this skill together with `ios-ui-implementation` for visible native UI work.
- Use this skill together with `swiftui-view-refactor` after extracting reusable views.