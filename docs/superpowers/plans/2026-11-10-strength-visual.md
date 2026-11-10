# Strength Visual Feedback Implementation Plan

**Goal:** Make strength progress the first visual story in Trends without changing recorded results or their meaning.

**Architecture:** Add local exercise selection to TrainingTrendsView and reuse ExerciseProgressChart with optional heading, explanation and identifier overrides. All overrides have defaults preserving History. Use ExerciseTrendSummary.progress and the existing exact set/comparison projections.

**Tech stack:** SwiftUI, Swift Charts, existing Senda domain/logger, Swift Testing and XCTest.

**Spec:** `docs/superpowers/specs/2026-11-10-strength-visual.md`.

**Files:** TrainingTrendsView.swift, ExerciseProgressChart.swift, Preview.swift, LoggerUITests.swift, README.md, this spec and plan (seven focused files).

- [x] Read current guidance/data/chart/navigation source and independently audit chart semantics; confirm user priority is strength first.
- [x] Capture baseline and run the new exercise-switching native test before product changes; expect missing trends-strength-picker.
- [x] Add shared chart overrides while keeping all default History headings/captions/identifiers and calculations intact.
- [x] Add the Strength progress exercise menu, plot, latest exact dated set, existing feedback and View history above comparisons. Keep valid selection and sensible fallback; no chart for empty windows.
- [x] Extend renders for weighted, bodyweight, added weight, one point, kilograms, fallback, long name and Larger Text. Verify native exercise/range/history/empty/workout-return and accessibility-size flows; pass full semantic suite.
- [x] Obtain independent final review, apply only baseline-checked files, and verify hashes/whitespace. No commit or push.

Review focus: chart metric changing with range/bodyweight data; flat loads with rep improvement; mixed load/reps changes; a one-point series; unavailable selection; long names and Larger Text; exact history context and pending workout preservation. Artifacts live under output/strength-visual in the review workspace.

## Verification

The new native exercise-switching check failed before product edits because trends-strength-picker did not exist. The completed iPhone 16 run passes three checks: strength exercise switching with aligned chart/latest values, 8/12-week changes and read-only History; empty Trends without a chart/picker; and the existing workout/history return flow with saved values intact.

The compact iPhone 13 mini Largest Text case passes exercise selection, chart identity, reachable 44-point controls, exact latest values, History access and return to the week. Native visual review found crowded X-axis dates. At accessibility sizes the shared chart now uses a 6/4-week tick interval instead of ordinary 3/2 weeks; every recorded point remains present, and History's heading/caption/identifier defaults remain unchanged. The final native image has a fully readable date label without overlap or truncation, plus the exact 65 lb × 8 set and View history.

The final full semantic suite passes 455 tests in 57 suites. Fresh render coverage includes six-point weighted progress, flat load with more reps, kilograms, body-weight reps, added weight returning to body-weight-only sets, one point, empty/old history, an unavailable selected exercise falling back within eight weeks, and a long custom exercise name at narrow/Larger Text sizes. An initial long-name preview was rejected by the existing library validation because its short name duplicated a preset; the synthetic fixture now uses its unique full name. No library validation was changed.

Independent review closed two copy/visual findings: clarify that body-weight sets plot at zero added load, and reduce date-label density at accessibility sizes. No actionable findings remain. Latest-set comparison semantics and chart calculations remain unchanged. No aggregate strength score, estimated max or missing-day data was introduced.

Applied seven baseline-checked files with matching destination hashes and clean focused whitespace checks. Domain/logger/persistence, other screens, brand, palette and bottom bar remain unchanged. Source backups, patch, manifest, logs and captures live under output/strength-visual in the review workspace. No commit or push.
