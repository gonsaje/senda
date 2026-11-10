# Workout accessibility validation — November 9, 2026

The two original workout warnings and the additional findings exposed by the expanded audit are resolved. All eight final workout audits pass with zero issues on the exact source recorded in `tested-source-hashes.json`. Every audit category remains enabled; the handler records each issue and returns false.

| Workout state | iPhone 13 mini | iPhone 16 |
|---|---|---|
| Empty workout | Pass | Pass |
| Blank set | Pass | Pass |
| Populated set | Pass | Pass |
| Two repeated sets, with Undo | Pass | Pass |

## Changes

- New set and Repeat keep one native action tree as AnyLayout adapts their arrangement for Larger Text.
- Short weekday/date names match visible text. The shortened date supplies the year as its accessibility value.
- Compact screens and intermediate larger text use labeled Weight/Reps values side by side; values stack from xxxLarge. Wider default layouts retain larger, individual column headings.
- The compact set number and selected type form one native button, preserving the picker action and exposing the visible type in its name.
- Undo uses one native “Undo last change” button with a 44-point minimum label height. Its accessibility value identifies the operation. The inspected compact target is 291 × 44 points.
- Save status shows the model’s actual state directly. Removing the brief Saved pulse avoids overlapping text. Its local text color has approximately 5.57:1 contrast on ivory; the global palette is unchanged.
- Header icon targets can grow with text, and Week stays whole at the largest accessibility text size.

## Verification

- Eight final all-category workout audits: 8 passed, 0 issues.
- Final isolated mini run: repeat/delete/Undo and continuing into the next set without dismissing the keyboard both passed. The Undo target-height assertion passed.
- 455 semantic tests in 57 suites passed.
- Final simulator test build and unsigned physical-iPhone build passed.
- Earlier focused runs verified separate set-type saving, grouped Drop stages, optional effort separation and keyboard editing. Largest-text editing passed on both phones after the Week fix.
- Native screenshots and hierarchies confirm actionable Button roles, complete Week labels and reachable Next set/Done/input controls. See `screenshots/`.

Earlier mini runs encountered a three-minute test limit and a screenshot-service timeout. The final isolated Undo/keyboard run passed without app-source changes between the final audits and that run. Earlier failed and superseded result bundles remain under `/private/tmp/senda-iphone-results/`.

## Scope and remaining check

Tests use unique synthetic journals. Real user journals were not reset or edited. The merged staging source preserves the newer workout, logger and app-icon changes in the actual repository. Integration verifies the 716-file snapshot and writes only the three reviewed source/test files and two verification notes. No commits or pushes.

A physical-iPhone VoiceOver session remains pending. Automated audits do not establish spoken focus order, rotor behavior or real-device announcements.
