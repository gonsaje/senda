# Workout UX reset and grouped Drop sets

The [UI/UX audit](../design/2026-11-09-ui-ux-audit.md) identified task priority and row density as the main problems. The first repair pass changes structure rather than adding decoration:

- A compact date toolbar and one exercise selector replace the duplicate tabs/title hierarchy. All exercises, hiding, Add, history and unit changes remain accessible.
- Ordinary narrow-screen weight and reps stay alongside each other. Larger Text can stack values. Type retains its own prominent control and 44-point target.
- Empty effort controls no longer add a line to every set. Row actions contain Reps left; a saved effort value appears quietly inline.
- Last/best references start collapsed. Save errors and Retry stay pinned above the bottom controls, and guidance is withheld while a save error is active.
- Learn back and Progress Back/Done stay outside scrolling content. Progress uses a smaller heading preamble; Learn puts form cues before the detailed muscle map.

## Working is the standard type

Working set is now the default and the only standard selectable type. The stored Regular enum remains for compatibility and displays/selects as Working; loading a file does not reclassify or rewrite it. Warm-up and Drop set remain distinct choices. The legacy alias still counts toward Working targets, preserving prior meaning.

## One Drop entry, multiple saved stages

Rows retain independent numeric input, raw draft text, canonical weight, action IDs and performed-set IDs. An optional shared dropGroupID makes explicit, contiguous membership. The screen derives one entry with Start, Drop 1, Drop 2 and Add drop. Stage input uses the existing automatic save path and identifies the set and stage in the input dock and accessibility labels.

The entry counts once in day/week, progress and Trends set totals. Every saved physical stage remains available in history, best-set comparisons and value-based calculations. History labels the logical set count and the number of saved Drop stages separately. Invalid stage input preserves its raw text and the last valid observation. Legacy Drop rows without a group are never silently joined.

Adding a stage creates a blank editable row; repeated Add does not multiply an untouched trailing stage. An individual stage can be removed. Whole-entry delete removes every stage atomically. Repeat creates a fresh group and fresh row/action/performed IDs, preserves canonical values and clears effort. Changing a multi-stage Drop entry to Working or Warm-up separates its stages, retaining values; the chooser explains the split.

Grouped Undo uses one removal token per affected journal batch. Partial-batch restoration checks the exact expected remaining batch and revision before restoring the original values once. Validation checks group scope, contiguous membership, Drop classification, ID collisions, undo metadata and unique original batch positions. The app retains only its current Undo operation and clears it on newer intent. As in the preexisting single-set domain API, low-level fully removed batch tokens have no deletion-generation stamp; replay hardening outside the app's latest-Undo flow remains a separate engineering task.

Drop workouts continue to require manual load review rather than qualifying for automatic standard-set progression suggestions.

## Compatibility

Local storage writes format 7 and reads formats 1–7. Full backups write version 4 and read versions 1–4. Loading older data does not rewrite it. New grouping and Undo data have explicit version boundaries so older apps reject the format rather than silently dropping membership. CSV adds group ID and stage columns, including physical stage order when an incomplete stage creates a gap. Restore previews use logical set counts.

## Verification

The combined candidate package passed 438 tests in 56 suites. Focused RED/GREEN runs covered Working defaults and legacy aliases, grouping persistence, grouped edits and autosave failures, canonical precision, civil dates, repeat/dedup/retry, individual and whole-group deletion/Undo, shared historical batches, type splitting, logical counts, old file formats, full backups, CSV and validation edge cases. Final layout/recovery builds also passed the 11 grouped workflow tests. Updated iOS UI acceptance source parses; no iOS runtime is available here.

An independent source review found no blocking data-loss/retry defect. Native renders cover ordinary/compact/Larger Text logging, grouped stages, active stage editing, saved history, failures/retry and Learn navigation. A visual review caught and corrected More-menu alignment and offscreen save-error recovery. Numeric values and essential touch targets were retained.

These are native macOS renders, not device or simulator verification. On-device keyboard, VoiceOver, menu presentation and real lifting-session usability still need validation before release. The remaining audit backlog covers exercise-picker preamble, Trends hierarchy, Profile ownership and a shared component/type system.

Use `senda-preview --ux-review-only /absolute/output/directory` for focused checks. Baseline and final renders are preserved under `/Users/jaesong/Documents/ChatGPT/senda/output/ux-review/`.

Applied-package verification passed 438 tests in 56 suites. The 17 final UX captures were checked for freshness after applying all reviewed source changes. The short failed-save captures show Retry pinned above navigation.
