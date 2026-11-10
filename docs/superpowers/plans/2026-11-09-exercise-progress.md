# Exercise progress implementation plan

> For agentic workers: implement isolated file-owned tasks with test-first domain/model work, followed by whole-change review and verification.

**Goal:** Deliver8/12-week per-exercise history and observed trends without losing the current workout.
**Architecture:** Pure snapshot projections, ephemeral progress navigation on the notebook model, SwiftUI modal catalog/detail/session views and native Charts.
**Tech stack:** Swift 6, Foundation, SwiftUI/Charts, iOS 17/macOS 14, Swift Testing.
**Spec:** docs/superpowers/specs/2026-11-09-exercise-progress.md

## Global constraints
No analytics storage/schema change or dependencies. Use actual recorded values and exact set identities. Monday calendar weeks through today; default 12 or8. Preserve current-workout context. Keep existing Senda colors/type and 44-point controls. No commits/pushes or live personal-data edits during validation.

## Review focus
- Re-bucketing recorded timestamps after timezone change must not move linked training dates.
- Bodyweight and added load must not share a misleading reps/weight axis.
- Draft corrections/deletion/Undo/restore must recompute from performed history.
- Empty/sparse/zero weeks must not fabricate strength data.
- Failed then canceled progress navigation must never reopen an old modal during retry.

## Tasks
- [x] Pure ExerciseProgress domain types/query and meaningful RED/GREEN edge tests.
- [x] Model open/close/return boundaries, superseded retries and restore cleanup; RED/GREEN workflow tests.
- [x] Public TrainingProgressView catalog/detail/read-only recorded sets and accessible daily/weekly charts.
- [x] Profile/active-exercise entry, root presentation and native preview fixtures; iPhone UI-test source and README/implementation notes.
- [x] Full suite, native full/compact/sparse/bodyweight captures, independent review, guarded apply and applied-app verification.
