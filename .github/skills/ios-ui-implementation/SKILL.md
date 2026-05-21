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
- localize user-visible strings
- validate visible changes with a narrow build and a targeted manual or screenshot check

## Do Not

- hardcode colors, spacing, radii, shadows, or typography that belong in the theme
- move reusable rendering into one host screen unnecessarily
- create a one-off visual system separate from shared native utilities
- widen scope into backend or Android work unless the slice explicitly requires it

## Procedure

1. Read the relevant feature package and the nearest native implementation anchor.
2. Identify the reusable view boundary that should own the rendering.
3. Reuse existing `Theme` and shared native primitives before creating new styling.
4. Add missing semantic tokens to `Theme.swift` only when needed.
5. Implement the smallest useful UI slice.
6. Run a narrow build or check for the touched area.
7. Perform a targeted manual or screenshot-based verification for visible behavior.

## Notes

- For refactor-heavy UI work, also load `swiftui-view-refactor`.
- For async loading, polling, or task/cancellation-heavy work, also load `swift-concurrency-implementation`.
- For visually sensitive features, also load `ios-testing-validation`.