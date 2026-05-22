---
name: ios-ui-implementation
description: "Implement visible iOS UI in Naviari_IOS. Use when: translating approved UX into SwiftUI, styling views through Theme.swift and AppFont.swift, building reusable native components, updating CourseTimelineView or StartDetailScreen, or delivering iOS source-of-truth UI for Android parity."
user-invocable: true
---

# iOS UI Implementation

Use this skill when implementing visible UI in `Naviari_IOS`.

## Read First

- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.github/instructions/ios-native.instructions.md`
- `Naviari_IOS/Utilities/Theme.swift`
- `Naviari_IOS/Utilities/AppFont.swift`

Read nearby shared UI primitives when relevant:

- `Naviari_IOS/Views/ScreenContainer.swift`
- `Naviari_IOS/Views/RaceManagerButtonLabel.swift`
- `Naviari_IOS/Views/SplitActionButton.swift`
- `Naviari_IOS/Views/UserNotifications.swift`

If the work is feature-scoped, also read the active feature package in `../NaviariYleinen/features/`.

## Purpose

This skill exists to keep iOS UI implementation consistent with:

- shared native theme and typography
- reusable SwiftUI view boundaries
- existing Naviari interaction and layout patterns
- iOS-first source-of-truth work when Android parity depends on iOS

## Use When

- implementing approved SwiftUI UI changes
- building or refining reusable native views
- updating `CourseTimelineView.swift`, `StartDetailScreen.swift`, or similar native screens
- translating UX specs into iOS code
- adding or adjusting theme tokens for new approved visuals

## Do

- use `Theme.swift` and `AppFont.swift` systematically
- add missing reusable tokens to `Theme.swift` before using new visual values
- keep screens focused on composition, callbacks, and navigation
- keep rendering logic in reusable views where possible
- reuse existing native button, card, and notification patterns
- **localize every user-visible string in EN (`en.lproj`), FI (`fi.lproj`), and SV (`sv.lproj`)** — all three languages are required for every new key
- validate visible changes with a narrow build and a targeted manual or screenshot check

## Do Not

- hardcode colors, spacing, radii, shadows, or typography that belong in the theme
- move reusable rendering into one host screen unnecessarily
- create a one-off visual system separate from shared native utilities
- widen scope into backend or Android work unless the slice explicitly requires it

## Procedure

1. Read the relevant feature package (`ordered-tasks.md`, the active `task-XX-*.md` context doc, and any linked UX spec or design handoff). **Read the design/handoff document completely — all sections to the end — before writing any code. Do not start implementation after reading only part of the spec.**
2. Identify the reusable view boundary that should own the rendering.
3. Reuse existing `Theme` and shared native primitives before creating new styling.
4. Add missing semantic tokens to `Theme.swift` only when needed.
5. **Implement one ordered slice at a time.** Do not combine multiple slice IDs from `ordered-tasks.md` into a single changeset. Each slice is a separate bounded unit.
6. Run a narrow build or check for the touched area.
7. Perform a targeted manual or screenshot-based verification for visible behavior. For visually sensitive work, load `ios-testing-validation` to confirm the required evidence before marking the slice done.

## Keyboard Handling Standard

Every form screen that contains text or numeric inputs **must** implement scroll-and-dismiss behaviour, even when the feature spec does not mention it. This is a non-optional UX requirement.

Required pattern (see `ParticipateView.swift` as the canonical example):

1. Declare a `@FocusState` enum covering every input field in the view.
2. Attach `.focused($focusedField, equals: .<field>)` to each `TextField` or `TextEditor`.
3. Add a `.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }` toolbar so the user can close the keyboard via a "Done" button.
4. Wrap the form content in a `ScrollView` and apply `.scrollDismissesKeyboard(.interactively)` so the user can also dismiss the keyboard by scrolling down.

Never skip these four steps on a form screen. If a feature request does not mention keyboard handling, add it anyway.

## Localization Standard

Every user-visible string added to the iOS app **must** be localized in all three supported languages. This is a non-optional requirement — the same rule as keyboard handling.

Required steps for every new string:

1. Choose a descriptive `snake_case` key that follows the existing naming convention in `Localizable.strings` (e.g. `screen_section_element_action`).
2. Add the key with an English value to `en.lproj/Localizable.strings`.
3. Add the key with a Finnish value to `fi.lproj/Localizable.strings`.
4. Add the key with a Swedish value to `sv.lproj/Localizable.strings`.
5. In the view, reference the key via `NSLocalizedString("key", comment: "")` or `String(localized: "key")`. Never use a raw string literal for user-visible text.

If you do not have a confirmed Finnish or Swedish translation, leave a clear `// TODO: translate` comment beside the placeholder — do not silently use the English string in the other language files.

Never skip adding all three language entries. A slice is not complete until all three files contain the key.

## Notes

- For refactor-heavy UI work, also load `swiftui-view-refactor`.
- For async loading, polling, or task/cancellation-heavy work, also load `swift-concurrency-implementation`.
- For visually sensitive features, also load `ios-testing-validation`.