# Senda daily logging second pass Implementation Plan

> Use test-driven model implementation, isolated candidate files and an independent whole-change review. The audit and the user's request authorize this next pass; do not stop for another design approval round.

**Goal:** Reduce repeated setup and entry work without fabricating performed history.

**Architecture:** Reuse the main-actor snapshot transaction boundary for blank-row reuse, explicit prefilling, ordered bulk exercise addition and workout structure copy. Derive recent exercises and source references from performed history. SwiftUI consumes these projections and keeps pending picker actions consistent with retry/cancel behavior.

**Tech Stack:** Swift6, SwiftUI, Swift Testing, XCTest, existing local atomic persistence, iOS17/macOS14.

**Spec:** docs/superpowers/specs/2026-11-08-daily-logging-second-pass.md

## Global constraints

- Preserve first-pass behavior, schema compatibility, canonical weights, performed identities/dates and atomic writes.
- Keep ivory #F7F3EB, terracotta #A94E32, charcoal #302720 and the approved logo.
- No third-party app dependency, backend, cloud or user-branch commits/pushes.
- New/copy/prefill actions add no copied performed sets. Existing explicit finalization behavior remains.

## Review focus

- Empty vs partial rows; explicit zero and bodyweight; pending correction raw values must never become copy sources.
- Copy order, duplicate IDs, existing hidden tabs/drafts, custom/legacy exercises and source/destination date boundaries.
- Failed bulk/reuse transactions, repeated retries, changed selection and cancellation before background recovery.
- Recent uniqueness/ties and consistency of search/group/equipment filtering.
- Compact/large-text layouts and discoverability of retained counted exercises after hiding their tabs.

## Task1 Model workflows and regression tests

Files: TrainingNotebookModel.swift, focused new projection/helper file, new DailyLoggingTests and relevant persistence tests.

- [x] Write and run RED regression for New set creating a redundant blank row.
- [x] Implement blank-row reuse with stable identity and correct input focus.
- [x] Write RED cases for actual prior-set references and draft-only explicit prefill; implement exact shared interfaces in spec.
- [x] Test and implement ordered atomic add/reuse, hidden exercise index, recent projections and safe cancellation of unpublished failed actions.
- [x] Cover unit/bodyweight/zero, prior-date/source immutability, existing input, repeated calls, continued failure/retry/cancel and actual persisted reopen.
- [x] Run focused and full suite; provide RED/GREEN evidence. Do not edit live app or commit.

## Task2 Picker and reuse interface

Files: TrainingExercisePicker.swift, TrainingDayExerciseList.swift, new TrainingWorkoutReusePicker.swift; pure ExerciseSelectionFilter helper/tests.

- [x] Test consistent search/group/equipment intersection and Clear filters policy before implementing helper.
- [x] Add recent choices, All/default filters, meaningful empty states,44point targets and single/multiple selection modes.
- [x] Integrate atomic add/retry/cancel behavior without losing selections or presenting obsolete completion.
- [x] Implement dated workout structure chooser and hidden exercise restoration in All index.
- [x] Build and inspect regular/compact/accessibility layouts, coordinate first Day entry point with root.

## Task3 Day integration and verification

Files: TrainingDayView.swift, TrainingExerciseTabs.swift, LoggerUITests.swift, Preview.swift, README and implementation notes.

- [x] Add explicit previous-recorded-values action for blank rows and preserve pending-sheet recovery behavior.
- [x] Add Use a previous workout entry points and All count/Hide tab semantics.
- [x] Extend iPhone interaction source and native preview states for new workflows.
- [x] Run full suite and independently review the frozen candidate; fix material findings with appropriate regressions.
- [x] Apply only reviewed changed files after checking live-app hashes; verify applied app and refreshed preview.
