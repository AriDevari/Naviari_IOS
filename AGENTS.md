# Naviari_IOS Agents

## Canonical Shared AI Operating Model

This repo uses the shared Naviari AI-operating model.

The canonical shared layer lives in the sibling repo:

- `../NaviariYleinen/AI_setup/.ai-agents/`

Read these first when the task involves workflow, feature-package structure, handoffs, slice execution, or agent behavior:

- `../NaviariYleinen/AGENTS.md`
- `../NaviariYleinen/AI_setup/AI_AGENTS_SETUP_GUIDE.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/ai-agnostic-working-model.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/feature-package-model.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/iteration-loop.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/handoff-template.md`

Keep repo-local wrappers thin. Do not duplicate shared methodology here when the same guidance already exists in `../NaviariYleinen/AI_setup/.ai-agents/`.

## Repo-Specific Native Rules

- All user-visible iOS styling should come from shared native theme sources such as `Naviari_IOS/Utilities/Theme.swift` and `Naviari_IOS/Utilities/AppFont.swift`.
- If a visual value needed by a feature is missing, add a reusable semantic token to `Theme.swift` first and then consume it from the view.
- Do not introduce screen-local hardcoded colors, spacing, radii, shadows, or typography when the value belongs in the theme.
- Prefer reusable SwiftUI view boundaries over screen-owned rendering logic.
- Treat host screens like `StartDetailScreen.swift` as composition and callback surfaces, not as the long-term owners of reusable UI presentation.
- Preserve and extend shared view components such as `CourseTimelineView.swift` instead of duplicating the same presentation in multiple screens.
- Reuse existing native button, card, notification, and layout patterns before inventing one-off variants.
- Keep user-visible strings localized.
- When Android parity depends on iOS, iOS implementation is the source of truth only after the iOS state is validated and documented.

## Local Customization Files

- Copilot wrapper: `.github/copilot-instructions.md`
- File-scoped iOS instructions: `.github/instructions/ios-native.instructions.md`
- Focused iOS implementation agent: `.github/agents/ios-developer.agent.md`
- Local iOS skills:
	- `.github/skills/ios-ui-implementation/SKILL.md`
	- `.github/skills/swiftui-view-refactor/SKILL.md`
	- `.github/skills/ios-testing-validation/SKILL.md`
	- `.github/skills/swift-concurrency-implementation/SKILL.md`

## Feature Work

When the task belongs to a feature package, read the active package in `../NaviariYleinen/features/backlog/<feature-name>/` or `../NaviariYleinen/features/implemented/<feature-name>/` first.

Minimum expected reads for feature work:

- `feature-map.md`
- `ordered-tasks.md`
- active `task-XX-*.md` slice context artifact when present
- matching `report-XX-*.md` if continuing or reviewing an existing slice