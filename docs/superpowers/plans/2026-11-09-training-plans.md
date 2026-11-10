# Training Plans Implementation Plan

> For agentic workers: file-owned domain, model and UI implementation with test-first logic and independent review. No actual-repository commits/pushes.

**Goal:** Add truthful workout targets, warm-up/effort annotations and useful next-workout guidance.
**Architecture:** Optional day-scoped plans and row metadata in existing workspace; pure guidance projection; atomic model mutations and native editors. Local format5/backups2 protect new data from older readers.
**Tech Stack:** Swift6, Foundation, SwiftUI/Charts, iOS17/macOS14, Swift Testing.
**Spec:** docs/superpowers/specs/2026-11-09-training-plans-design.md

## Global constraints
Keep exact canonical weights, identities, civil-day links, recorded/draft/correction distinctions and transaction retry/restore behavior. No auto-created records or automatic load increases. Old metadata stays unknown. Plans are per-workout snapshots. No decorative left borders/cards, fake targets or motivational filler;44pt controls and stacked Larger Text.

## Review focus
Metadata edits cannot finalize numeric input. Legacy sets cannot become working sets by decoding defaults. Repeated/prefilled sets cannot inherit historical effort. Incomplete/mixed/changed-plan/unknown sessions block progression without cherry-picking. New fields must survive local persistence, full backup, restore and deleted-set Undo; invalid annotations are rejected.

## Tasks
- [x] Domain: TrainingPlan.swift, NextWorkoutGuidance.swift, TrainingWorkspace fields/validation; pure tests RED/GREEN including dates/plan match/unknown/warmup/correction/units/readiness boundaries. Frozen API in root handoff.
- [x] Model: plan/kind/effort mutations; safe plan inheritance/reuse/new row/repeat/prefill semantics; tests RED/GREEN for identity/draft/fail/retry/supersession/undo/restore.
- [x] UI: flat Plan summary/editor, row details, Next workout feedback, read-only metadata; native targets/failure state/compact/Larger Text; existing delete interactions preserved.
- [x] Persistence: local v5/backups v2, old compatibility, exact annotations/plans/undo JSON + CSV columns, invalid-data and atomic failure tests RED/GREEN.
- [x] Integration docs/fixtures/UI-test source, full suite, native visual review, independent review, guarded apply and final native preview verification.
