# Exercise progress

November 9, 2026

## History and trends
Progress opens from Profile or the active-exercise chart control. Its modal catalog searches exercises with recorded history, while direct links support a meaningful empty exercise state. The default 12-week range can switch to8; both use Monday calendar weeks through today and display exact date bounds, including the current partial week.

The pure JournalSnapshot.progress projection joins journal performed sets to saved day/row links, preserving local dates, actual row positions, canonical weights, and set/batch identities. Same-day batches become one session. Unfinished corrections keep their performed values; drafts never count. Hidden/custom/legacy exercises remain included. Legacy snapshots use calendar-local timestamp days only when no training workspace exists.

Daily points and straight segments show observed top sets. Weighted periods rank load then reps; all-bodyweight zero-load periods rank reps; mixed added-load periods show actual added weight, including zero for bodyweight-only days. Latest and period-best cards retain rep context and make no estimated-strength claim. Training rhythm shows recorded days for every week, including zero-frequency weeks. Native Swift Charts provides point labels/values; dated session values and expandable weekly counts provide text alternatives. [Apple Charts documentation](https://developer.apple.com/documentation/Charts/Chart).

## Current-workout continuity
Recorded days open a read-only list of exact performed sets inside Progress. This never navigates the notebook to a different historical day. Done returns to the originating screen, while Return to workout switches to Log with the selected day/exercise intact. Opening and returning use existing finalization/persistence boundaries. Failed actions retain retry; closing/canceling or a newer transaction supersedes old progress callbacks. Backup restore dismisses old progress and resets its selection. The active-exercise button clears any older pending Add/All sheet before opening.

## Verification
Test-first domain and model regressions cover period edges, DST/year changes, row gaps, same-day batches, hidden/custom/legacy work, bodyweight/mixed/zero values, exact canonical units and identities, drafts/corrections/delete/Undo, no-write browsing, cancellation/retry and restore cleanup. Native preview fixtures include catalog,12/8 weeks, compact, complete page, bodyweight, single day, empty period and accessibility layout. Product source and iPhone UI-test syntax are checked; full suite and guarded applied-file results are recorded in the delivery artifact.

Local Mac-hosted previews cannot certify actual iPhone chart exploration, VoiceOver or Dynamic Type; full Xcode/device checks remain a release validation step. No real user journal was edited during development, and no storage schema changed.
