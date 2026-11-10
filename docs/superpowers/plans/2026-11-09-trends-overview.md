# Trends overview implementation plan

> For agentic workers: use test-first file-owned parallel tasks, then independent whole-change review.

**Goal:** Add a useful whole-notebook Trends section and honest progress feedback.
**Architecture:** Pure TrainingTrends projection sharing history resolution with ExerciseProgress; native main-tab overview; existing modal history drill-in.
**Tech stack:** Swift6, Foundation, SwiftUI/Charts, iOS17/macOS14, Swift Testing.
**Spec:** docs/superpowers/specs/2026-11-09-trends-overview.md

## Global constraints
Keep all existing data behavior and pending-action recovery. No storage schema/dependencies or logo changes. Monday8/12-week windows through today. Exact canonical values and recorded identities, saved civil days, no draft/future counts. No fabricated targets/scores, decorative left borders or color-only feedback. Preserve uncommitted work; no commits/pushes.

## Review focus
- Overall days must deduplicate multiple exercises/batches on one day.
- Partial current week must compare the same elapsed days last week.
- Same-load/same-rep changes must use immediate prior day, not a favorable older set.
- First observations/ties must not become fake improvement or record events.
- Range/units/corrections/Undo/restore and failed navigation must remain coherent.

## Tasks
- [x] Domain projection/types and shared resolver; RED/GREEN trend cases and existing progress regressions.
- [x] Trends navigation, modal return and no-write overview workflows; RED/GREEN model tests.
- [x] Native Trends overview/feedback rows and shared range/frequency components.
- [x] Main-tab/root integration, Profile label, native fixtures/gallery, iPhone UI-test source and docs.
- [x] Full suite, native normal/compact/sparse/BW/mixed/decreasing states, independent review and guarded application.
