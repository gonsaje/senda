# Set type column

Set type is now a separate column with an outlined, full-size button. New sets default to Regular. Selecting Regular, Warm-up, Working set or Drop set saves immediately and closes the chooser. Each choice has a short definition and a checkmark for the persisted value. Reps left remains a separate optional control. Compact and Larger Text layouts use labeled stacked controls so numbers and tap targets stay readable.

A failed choice keeps the old type visible and offers Retry. A newer choice or dismissal supersedes an unpublished attempt; context checks prevent a delayed save from applying to a different day, exercise or row. Existing automatic numeric saving, raw input, canonical weights, set/action IDs, dates, deletion/Undo and effort annotations are preserved.

## Counting and guidance

Regular and Working set both count toward the workout's working-set target. Warm-up and Drop set remain in history and total set counts but do not count toward that target. The shared `countsTowardWorkingPlan` policy is used by the summary and guidance.

A latest Drop-only or mixed Drop workout prompts manual load review, and an intervening Drop workout breaks the pair of comparable standard sessions. This is a conservative rule for Senda's automated comparison; it is not a claim that Drop sets are ineffective. The selector describes reduced-load continuation and asks users to log each load separately. No load percentage, failure requirement, benefit claim or prescribed routine is added.

Existing Working set, Warm-up and unknown legacy annotations remain unchanged. Repeat preserves the chosen type and clears Reps left. Prefill preserves the destination type and exact canonical historical load, and clears effort.

## Compatibility

- Local journal writer: format 6; readers: formats 1–6.
- Full-backup writer: version 3; readers: versions 1–3.
- Older local files remain byte-for-byte unchanged when read; the next mutation writes the current version.
- CSV retains the existing columns and exports the stored type raw value.
- New type metadata round-trips through local saves, full backup, restore and CSV with exact weights, identities, dates, plans, effort and partial input.

## Verification

The candidate package passed 412 tests in 52 suites. The new default and guidance behavior, writer versions and compatibility were tested with failing assertions before implementation and passing assertions afterward. Coverage includes all four types plus legacy nil on repeat/prefill, target counts, latest/intervening Drop sessions, metadata failures/retries, exact kilogram values, old formats and future-version rejection.

An independent read-only source review found no P1/P2 issues. Ten actual native SwiftUI renders were reviewed: default Regular, all four kinds, compact and accessibility layouts, the chooser, failed save and successful Retry. The failed type remains Regular until persistence succeeds; Retry changes it to Warm-up and changes the target count accordingly. `git diff --check` and iOS UI test source parsing pass.

These are macOS native renders, not iPhone simulator or device tests. The updated iOS UI acceptance tests were not executed because an iOS runtime is unavailable here. Run `senda-preview --set-types-only /absolute/output/directory` for focused visual checks. The live gallery leads with this feature.

Applied-package verification passed 412 tests in 52 suites. All ten set-type renders were checked for freshness after applying the reviewed files, and the live gallery was refreshed.
