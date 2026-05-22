---
applyTo: "**/*.swift"
description: "Use when: editing SwiftUI or UIKit code in Naviari_IOS, including Theme.swift, AppFont.swift, StartDetailScreen, CourseTimelineView, reusable native components, native screen composition, or iOS source-of-truth UI work for Android parity."
---

Naviari iOS implementation rules:

## Pre-implementation gates (enforce before writing any code)

- **Branch check**: Verify you are on the feature branch, not `main`. If on `main`, stop, create the feature branch using the feature name as the slug, switch to it, and only then proceed.
- **Skill load**: For any UI implementation slice, load the `ios-ui-implementation` skill by reading `.github/skills/ios-ui-implementation/SKILL.md` before writing code. For visually sensitive slices, also load `ios-testing-validation`.
- **Full spec read**: Read the complete design handoff or UX spec document — all sections, to the end — before writing the first line of implementation code. Do not start coding after reading only part of the spec.
- **Slice boundary**: Implement one ordered task slice at a time. Do not combine multiple slice IDs from `ordered-tasks.md` into a single changeset. Each slice needs its own build check and validation evidence before the next slice starts.
- **Orchestrator first**: If the active feature package has more than one planned slice, do not begin implementation without first dispatching the `Orchestrator` agent to sequence and gate the work.

## Styling rules

- Styling must come from shared native theme sources such as `Naviari_IOS/Utilities/Theme.swift` and `Naviari_IOS/Utilities/AppFont.swift`.
- If a visual value is needed and not available, add a reusable semantic token to `Theme.swift` first and then use that token from the view.
- Do not introduce component-local hardcoded colors, spacing, radii, shadows, or typography when the value belongs in the shared theme.
- Prefer reusable view boundaries over screen-local rendering growth.
- Treat screens such as `StartDetailScreen.swift` as hosts that compose reusable views and own callbacks, loading state, and navigation, not as the long-term owners of reusable presentation.
- Extend shared views such as `CourseTimelineView.swift` when the same course presentation will later be reused elsewhere.
- Reuse existing native primitives and patterns before inventing one-off variants:
  - `ScreenContainer.swift`
  - `RaceManagerButtonLabel.swift`
  - `SplitActionButton.swift`
  - `UserNotifications.swift`
- **Localization is mandatory**: every user-visible string must be added to `en.lproj/Localizable.strings`, `fi.lproj/Localizable.strings`, and `sv.lproj/Localizable.strings`. All three languages are required — adding a key to one or two languages is not acceptable. Never hardcode a raw string literal in a view; always use `NSLocalizedString("key", comment: "")` or `String(localized: "key")`.
- For feature work, read the active feature package in `../NaviariYleinen/features/` before implementation.
- For Android-parity features, iOS becomes the source of truth only after the iOS behavior is validated and documented.

Validation expectations:

- After each substantive iOS edit, run the narrowest available build or validation for the touched slice.
- For visually sensitive work, include screenshot-based or real-device manual verification. Do not use the Xcode simulator — it is not available on this Mac. All physical testing is done on a real iPhone.
- Confirm theme-token use and reusable-view boundaries as part of validation, not only visual output.