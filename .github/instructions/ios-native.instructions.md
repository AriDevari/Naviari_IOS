---
applyTo: "**/*.swift"
description: "Use when: editing SwiftUI or UIKit code in Naviari_IOS, including Theme.swift, AppFont.swift, StartDetailScreen, CourseTimelineView, reusable native components, native screen composition, or iOS source-of-truth UI work for Android parity."
---

Naviari iOS implementation rules:

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
- Keep user-visible strings localized.
- For feature work, read the active feature package in `../NaviariYleinen/features/` before implementation.
- For Android-parity features, iOS becomes the source of truth only after the iOS behavior is validated and documented.

Validation expectations:

- After each substantive iOS edit, run the narrowest available build or validation for the touched slice.
- For visually sensitive work, include screenshot-based or simulator-based manual verification.
- Confirm theme-token use and reusable-view boundaries as part of validation, not only visual output.