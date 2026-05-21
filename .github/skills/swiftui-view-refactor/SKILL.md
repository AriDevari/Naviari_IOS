---
name: swiftui-view-refactor
description: "Refactor SwiftUI views in Naviari_IOS. Use when: extracting reusable views from screens, reducing StartDetailScreen-owned rendering, stabilizing bindings and callbacks, decomposing large SwiftUI files, or preparing shared iOS presentation for later reuse such as race-level course display."
user-invocable: true
---

# SwiftUI View Refactor

Use this skill when a SwiftUI surface needs structural cleanup or reuse-oriented decomposition.

## Read First

- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.github/instructions/ios-native.instructions.md`
- the current screen file
- the current reusable child view file, if one already exists

If the refactor is feature-scoped, also read the active feature package in `../NaviariYleinen/features/`.

## Purpose

This skill exists to keep SwiftUI code maintainable by preserving a clear split between:

- host screens that own composition, callbacks, loading state, and navigation
- reusable views that own rendering and local presentation behavior

## Use When

- extracting a reusable view from a large screen
- moving row or card rendering out of a host screen
- cleaning up bindings, callbacks, and local state boundaries
- preparing a UI surface for reuse on another screen
- reducing duplication between native views

## Do

- identify the smallest reusable presentation unit first
- keep callback and navigation ownership explicit
- move rendering logic into a shared child view when that presentation will be reused
- preserve feature behavior while reducing screen-owned rendering
- validate the refactor before broadening scope

## Do Not

- refactor broad surrounding surfaces just because they are nearby
- hide important data flow inside opaque helpers
- move navigation or orchestration responsibilities into a reusable presentational view
- change styling rules independently of `Theme.swift`

## Procedure

1. Identify the current host screen and the candidate reusable view boundary.
2. List which concerns stay in the host and which move into the reusable view.
3. Extract the smallest rendering slice that improves reuse.
4. Preserve external behavior and callback wiring.
5. Run the narrowest validation for the touched view.
6. Stop after the refactor slice is stable; do not chain unrelated cleanup into the same change.

## Notes

- This skill pairs well with `ios-ui-implementation` when the refactor includes visible UI updates.
- Use `ios-testing-validation` to verify behavior after the first substantive refactor edit.