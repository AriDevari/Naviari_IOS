# Copilot Project Instructions

This repo uses the shared Naviari AI-operating model.

## Canonical Source Of Truth

Treat `../NaviariYleinen/AI_setup/.ai-agents/` as the canonical shared AI-operating layer.

Read these first when the task involves workflow, orchestration, feature-package structure, handoffs, or agent behavior:

- `../NaviariYleinen/AGENTS.md`
- `../NaviariYleinen/AI_setup/AI_AGENTS_SETUP_GUIDE.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/ai-agnostic-working-model.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/feature-package-model.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/iteration-loop.md`
- `../NaviariYleinen/AI_setup/.ai-agents/shared/handoff-template.md`

`AGENTS.md` and `.github/` in this repo are local wrapper layers. Keep them aligned with the shared AI-agnostic layer.

## Local iOS Rules

- For Swift files, follow `.github/instructions/ios-native.instructions.md`.
- Use `.github/agents/ios-developer.agent.md` when the work is a bounded iOS implementation slice.
- Load local iOS skills when the task needs a repeatable workflow rather than only always-on rules:
	- `ios-ui-implementation`
	- `swiftui-view-refactor`
	- `ios-testing-validation`
	- `swift-concurrency-implementation`
- Keep host screens as composition surfaces and keep reusable visual logic in shared views.
- Use `Theme.swift`, `AppFont.swift`, and existing shared primitives as the styling source of truth.
- If a styling value is missing, add it to `Theme.swift` rather than hardcoding it in one screen.