# Trends Refinement Implementation Plan

**Goal:** Make Trends easier to scan and its history/records easier to reach.

**Architecture:** Refine `TrainingTrendsView.swift` and the accessibility layout of the shared period control. Keep existing domain/model calculations and navigation. Add a focused `--trends-only` option to the preview renderer and native overview attachments to existing coverage.

**Spec:** `docs/superpowers/specs/2026-11-09-trends-refinement.md`.

**Constraints:** Preserve current colors, Georgia headings, flat rows, minimum 44-point targets, full dates/values and Larger Text. No decorative left borders; no changes to week, workout, branding, range-selection behavior, storage or calculations.

- [x] Inspect current source, fresh rich-data renders and existing navigation coverage; capture native baseline.
- [x] Move Records into the adaptive header; keep expanded All-time records above the selected-period content.
- [x] Add a shared Top-set comparisons heading and reduce repeated row wording and ordinary spacing; retain dated sources and accessibility wording.
- [x] Render all existing Trends fixtures, inspect regular/compact/Larger Text states, run the full semantic suite and focused native range/history/PR/empty checks.
- [x] Obtain independent review; apply only baseline-checked focused files and verify final hashes/whitespace.

This refinement changes presentation and location of existing controls, so it receives visual checks and existing navigation tests. New tests that merely mirror spacing or copy are unnecessary. Keep reproduction artifacts in the review workspace under `output/trends-refinement`.

## Verification

The full semantic suite passes 455 tests in 57 suites. Native iPhone checks passed for empty Trends, eight/twelve-week selection, read-only history and the unchanged workout return, all-time PR inspection and explicit historical correction, and exercise-history catalog lookup. The iPhone 13 mini Largest Text case verifies reachable History/Records actions, expanded records, selected range and a return to the week. It also captures the ordinary overview and verifies the shared range control in exercise history.

One iPhone16 record-navigation run timed out while synthesizing a tap on exercise-search during setup, before reaching Trends. The unchanged isolated case passed on rerun in61.5seconds. No app or test-helper workaround was introduced for that automation timeout.

Fresh SwiftUI renders cover ordinary/compact/Larger Text, 8/12 weeks, mixed load/reps changes, bodyweight, kilograms, one-day, old-history and empty states. Native visual review found an existing selected-range word-breaking issue at the largest text size; stacking the shared buttons at accessibility sizes resolves it in both Trends and exercise history, while ordinary layout and selection behavior remain unchanged. Final native captures show complete range labels and clear status-bar text. The records header and dated comparison rows retain their source values and destinations.

Independent source and native visual review closed without remaining actionable findings in Trends or the range control. Applied seven focused files after destination baseline checks; all hashes match the reviewed source. Protected calculations, workout, week, branding and bottom bar remain unchanged. No commit or push was made.
