# Senda premium logging first pass Implementation Plan

> **For agentic workers:** Use test-driven implementation for model behavior and independent review before applying the finished candidate. Steps use checkbox syntax for tracking.

**Goal:** Make core logging safer, clearer and accessible while preserving the existing notebook visual language.

**Architecture:** Extend existing domain row validation and the main-actor transactional model. Keep performed history separate from pending corrections, make save recovery replay the intended transaction, and consume explicit state in SwiftUI. Prepare in an isolated copy and apply only verified changed files to the app.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XCTest, local atomic JSON persistence, iOS 17 and macOS 14.

**Spec:** docs/superpowers/specs/2026-11-08-premium-logging-first-pass.md

## Global Constraints

- Preserve ivory #F7F3EB, terracotta #A94E32, charcoal #302720 and the approved bundled logo.
- No cloud, account, backend or new third-party app dependency.
- Preserve integer canonical hundredths of a pound, performed identities, dates and snapshot atomicity.
- Legacy snapshots remain readable. No silent migration of drafts into history.
- Do not modify existing unrelated work or publish, merge, push or commit to the user's current branch.

## Review Focus

1. Incomplete corrections across row/day/exercise switches, relaunch, unit changes and delete/Undo.
2. Retry while storage continues failing, double retry, new input superseding an old failed action, and non-snapshot navigation effects.
3. Bodyweight/zero-weight rows and syntactically partial weights remain distinct from untouched blank rows.
4. Date rollover, restored previous days and Go to today never move drafts or create sets.
5. Compact/accessibility entry retains field/unit context, complete values, and reachable primary actions.

## Task 1 Model recording and recovery

Files: Sources/SendaDomain/TrainingWorkspace.swift; Sources/SendaLogger/TrainingNotebookModel.swift; focused new row-state file if helpful; Tests/SendaLoggerTests and Tests/SendaPersistenceTests; only directly relevant domain tests.

Interfaces: Produce exactly the row status, saved values, discard, unfinished count, retry and openToday APIs in the spec. UI consumes them in Task 2.

- [x] Write failing tests for incomplete correction preservation, valid completion with stable identity, discard, meaningful draft counts, legacy decode, and relaunch.
- [x] Run the focused tests and confirm failures before implementation.
- [x] Implement minimal durable pending-correction handling with strict reference validation.
- [x] Write failing tests for continued retry failure, successful exact-once Done/day/section retry, superseding input, date jump preserving drafts, and existing unit/delete/Undo interactions.
- [x] Implement safe failed-transaction recovery and openToday; pass focused tests.
- [x] Run the full suite and report evidence. No app-repo commits.

## Task 2 State presentation and adaptive entry

Files: Sources/SendaNotebook/TrainingDayView.swift, TrainingInputDock.swift, TrainingNotebookView.swift, and a focused row view/helper if needed. No domain/model edits. Consume Task 1's interfaces.

- [x] Add meaningful row states and discard affordance with recorded-value context, plus unfinished day indicators.
- [x] Add historical-day/Go to today affordance; wire actual retry action and preserve accessible error context.
- [x] Compact context during editing; scale numerals and stack rows at accessibility sizes. Keep labels and units visible and primary tap areas generous.
- [x] Add heading semantics, deliberate VoiceOver editor focus/outcome feedback and Reduce Motion handling.
- [x] Build and inspect regular, compact, empty, unfinished, correction and accessibility layout renders. Add meaningful UI-test coverage where feasible; iPhone execution requires full Xcode.

## Task 3 Integration and verification

Files: Tests/SendaUITests/LoggerUITests.swift, Sources/SendaPreview/Preview.swift, README.md and implementation notes as needed. Root owns these files.

- [x] Extend iPhone interaction tests for preserved history, discard, Go to today and visibly distinct unfinished states. Preserve existing test intent and adapt obsolete recording assertions.
- [x] Extend real SwiftUI renders to include the new immediate states and compact layouts.
- [x] Run the full project test command and review compiler output.
- [x] Obtain independent source review; resolve material findings with regression tests and repeat affected checks.
- [x] Compare each changed candidate file against the original captured source hash; apply only cleanly matching changes. Leave unrelated files and existing branding intact.
- [x] Verify the app copy, refresh its preview and report results plus the iPhone testing limit.
