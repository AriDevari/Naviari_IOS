---
name: swift-concurrency-implementation
description: "Implement Swift concurrency in Naviari_IOS. Use when: adding async/await flows, handling Task cancellation, isolating MainActor UI updates, coordinating async loading in SwiftUI screens, or refining concurrency behavior in iOS source-of-truth features."
user-invocable: true
---

# Swift Concurrency Implementation

Use this skill when async behavior is central to an iOS slice.

## Read First

- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.github/instructions/ios-native.instructions.md`
- the touched async/loading code path

If the work is feature-scoped, also read the active feature package in `../NaviariYleinen/features/`.

## Purpose

This skill exists to keep async iOS implementation predictable by making:

- main-actor UI updates explicit
- cancellation behavior intentional
- loading and refresh flows easy to reason about

## Use When

- implementing `async`/`await` in Swift code
- adding or fixing `Task`-based screen logic
- handling polling, refresh, or fetch flows in SwiftUI
- tightening main-thread and actor boundaries
- stabilizing async state for a reusable view or host screen

## Do

- keep UI-bound state updates on the main actor
- make cancellation behavior explicit when tasks can outlive a view state change
- prefer clear async control flow over callback nesting
- keep async orchestration in the appropriate host or view model layer
- validate with the narrowest behavior check after the change

## Do Not

- spread async side effects across multiple layers without clear ownership
- hide cancellation-sensitive behavior inside unrelated view code
- mix rendering refactors and concurrency changes unless the slice truly requires both

## Procedure

1. Identify the async owner: host screen, service, or reusable view.
2. Make actor boundaries explicit.
3. Add or adjust the smallest async behavior needed.
4. Verify cancellation, loading, and success/failure states.
5. Run the narrowest executable validation plus any needed manual check.

## Notes

- Pair this with `ios-testing-validation` whenever async behavior is user-visible.
- Pair this with `ios-ui-implementation` if the async slice changes visible SwiftUI state.