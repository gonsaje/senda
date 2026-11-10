# Workout Refinement Implementation Plan

**Goal:** Clean up workout spacing and provide direct weight → reps → next-set entry.

**Architecture:** Refine existing SwiftUI views. Extend `newSet(keyboard: Bool? = nil)` inside the existing single commit; default callers retain their previous focus behavior. No persistence or schema change.

**Spec:** `docs/superpowers/specs/2026-11-09-workout-refinement.md`.

**Constraints:** Preserve the current palette, Georgia headings, type column, numeric size, drop groups, autosave, partial input and failure recovery; 44-point minimum targets. No decorative left borders. No commits or pushes.

- [x] Add focused model coverage for keyboard continuation, defaults/reuse and atomic failure/retry; observe failure and implement the optional keyboard argument.
- [x] Add native flow coverage for direct continuation, incomplete input and earlier-row editing; observe the missing-flow failure.
- [x] Refine the editor actions/ruler visibility, plan action and compact spacing in `TrainingInputDock.swift`, `TrainingPlanSummary.swift` and `TrainingDayView.swift`.
- [x] Run the integrated semantic suite and relevant native entry, compact, Larger Text and drop-set checks; inspect native overview/typing/reps/next-set captures.
- [x] Obtain independent review and apply only focused baseline-checked files; verify hashes and whitespace.

Root owns the view and UI-test changes; the model agent owns `TrainingNotebookModel.swift` and `DailyLoggingTests.swift`. Their only shared interface is the optional keyboard argument. The root runs the integrated checks after both edits are ready. Reversible spacing and copy changes receive visual verification rather than implementation-mirroring tests.

## Verification record

The focused model tests initially failed for the missing keyboard argument, then all 23 DailyLogging tests passed after the two-line extension. The new iPhone flow test failed against the old editor because its ruler stayed visible while typing, then passed after the refinement. It checks incomplete/zero reps cannot continue, values survive returning to the dial, a new working set receives typing focus, earlier-row editing cannot append a set, and the final summary contains exactly two saved sets.

The integrated semantic suite passes 455 tests in 57 suites. Native iPhone 16 checks passed for direct continuation, decimal typing/dial adjustment and grouped drop-stage save/repeat/remove/delete. Native iPhone 13 mini checks passed for continuation and the largest accessibility text size. Final visual review identified status-bar overlap and truncated accessibility action labels; scrolling is now clipped to the layout bounds, and accessibility context sits above intrinsically sized action labels. Final captures and targeted checks verify these refinements before application.

The 44-point keyboard-dismiss action is available only for weight typing at sizes with a visual dial. It changes focus only, leaving raw input and saved values untouched. Normal callers retain their existing weighted-dial/bodyweight-typing defaults. The continuation uses the existing single atomic commit and retry machinery; no save format changes.

Final product-source checks passed for continuation on both iPhone sizes and for the largest text size on iPhone 13 mini. A screen-coordinate height check returned 43.999999999999986 for a declared 44-point control; the assertion now allows 0.01-point floating-point tolerance, and the case passes. Final native visual review confirmed full accessibility action labels, clean status-bar text, and readable ordinary workout/entry views. No actionable findings remain in scope.

Applied nine focused files after destination baseline checks. All applied hashes match the reviewed source; protected week, brand and bottom-bar files are unchanged. No commit or push was made.
