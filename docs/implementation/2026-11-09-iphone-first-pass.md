# iPhone first-pass progress

Plan: docs/superpowers/plans/2026-11-09-iphone-first-pass.md

- Baseline: 438 tests in 56 suites passed.
- Ruling: use an isolated temporary copy of the dirty working tree and compare baseline hashes before applying. This preserves the user's uncommitted app work without a branch, commit or worktree mutation.
- Ruling: the user's explicit first-pass instruction approves the reviewed scope and native implementation; no additional design confirmation is required.
- Ruling: all-date Recorded days supplies older-history access. Calendar navigation is deferred to keep this pass focused.
- Pre-flight: history/model changes are independent of visual layout; model state is consumed by the history sheet and persistent historical-edit return control.

## Implementation

- Workout plan completion, rep target and collapsed references share one band. Type controls, 24-point base numeric values, compact paired fields and Larger Text stacking remain. Previous-workout and previous-set wording now have distinct meanings.
- All-date Recorded days reuses the journal's saved-date and performed-value resolution while charts remain limited to 8/12 weeks through today. Intentionally future-dated records stay inspectable.
- PRs and workout references open the exact saved day and set read-only. Explicit historical editing captures only navigation fields; return commits edits and restores the original day/exercise or week without restoring an old data snapshot.
- Failed historical-edit destinations are cancelled on Done, swipe dismissal, Back, exercise/day selection or range changes. A reproduced cancellation failure was fixed and covered by close/swipe and browse-away regressions. History save recovery stays visible above the bottom edge.
- Trends begins directly with comparisons; dates and source values remain visible, with compact rows where they fit and Larger Text fallbacks. All-time record expansion has a distinct accessible button.
- iPhone checks exposed inherited identifiers on history/record containers and numeric/reference hit areas smaller than their layout frames. Identifiers now stay scoped to their controls and full rectangular touch areas are explicit.

## Verification

- Baseline: 438 tests in 56 suites. Updated semantic suite: 451 tests in 57 suites passed.
- Independent code review approved the navigation/cancellation fix; independent visual review found no visible regression.
- Matched Mac previews at 320-point width: first weight/reps values approximately 55 points earlier; first Trends comparison approximately 82 points earlier. These are layout observations, not physical-device benchmarks.
- Standard, compact, Larger Text, grouped Drop, editing, failure/retry, all-date history, selected PR and historical-return previews are in `/Users/jaesong/Documents/ChatGPT/senda/output/iphone-first-pass/after/`.
- Physical-device testing and a full VoiceOver audit remain outside this pass. Focused iPhone simulator outcomes are recorded with the final integration result below.

## Native-check follow-up

- Ruling: the largest-text set-type definitions made an option button taller than the viewport. At accessibility sizes, the choice title/checkmark remains a full-width button and its unchanged definition follows as readable text. Normal text presentation and immediate saving are retained.
- The exercise search already supports submitting Search to dismiss the keyboard. The UI setup now uses that action before choosing a result; the largest-text logger check uses a native vertical swipe to reveal the set. No picker behavior was changed.
- The Plan summary and all-time records now use explicit accessibility containers, preventing their identifiers from replacing child control identifiers. Plan, numeric, reference, date and History Done controls use their complete touch frames.

## Final validation

- Semantic suite: 451 tests in 57 suites passed on the final app source.
- iPhone 16: recent exercise history, exact reference browsing/editing/return, numeric targets and complete all-time PR correction/return workflows passed.
- iPhone 13 mini: all-time PR correction/return, compact numeric/Plan targets, live plan completion and largest accessibility-text set-type/effort workflows passed.
- Full native iPhone result bundles/logs are retained under `output/iphone-first-pass/ios-verified/`, `ios-final-check/`, `ios-compact-check/` and `ios-larger-text-verified/` in the review workspace. Earlier failed runs are retained for traceability. These are focused checks, not a claim of a full device or VoiceOver audit.
- Code review approved the navigation, cancellation and scoped accessibility layout changes. No commits or pushes were made.

## Integration

Applied 19 focused files to `/Users/jaesong/src/senda` after checking every target against its captured baseline. Verified all applied file hashes against the tested staging copy. Unrelated uncommitted work was retained. No commits or pushes.
