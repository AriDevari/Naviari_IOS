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

## Procedure

1. Identify the narrowest build, test, or runtime check for the touched slice.
2. Run it immediately after the first substantive edit.
3. For visible UI work, perform a targeted simulator or screenshot check.
4. Confirm theme-token use, localization, and reusable-view ownership where relevant.
5. Record the result in the slice report or task notes.

## Validation Checklist Ideas

- build succeeds for the touched iOS target
- no new hardcoded visual values where `Theme` should own them
- host screen still hosts; reusable view still renders
- one-open / tap / loading / error behavior still works as expected
- visual hierarchy matches the approved slice

## Notes

- Use this skill together with `ios-ui-implementation` for visible native UI work.
- Use this skill together with `swiftui-view-refactor` after extracting reusable views.