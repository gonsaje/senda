# Weekly training notebook — design and implementation plan

The user's consolidated edit list confirms Week → Day → Exercise navigation, automatic logging without recording buttons or checkboxes, separate New set / Repeat last set actions with targeted undo, and muscle-group browsing with equipment filtering. The user separately confirmed that valid sets count when editing finishes, incomplete rows do not count, Common is removed, Last and PR are separate banners, and lb/kg is a switch beside Weight. The supplied three-panel image is the visual reference; unconfirmed recommendations are not independent feature requests.

## Design

- Use the existing native SwiftUI package, palette, typography, local repository and pure Journal. Add a weekly application model and domain workspace alongside the existing logger. Preserve approved planning/architecture documents and existing performed IDs/action receipts.
- Open on a Monday–Sunday week list. Seven day rows show performed exercise names and actual set totals, with a subtle today highlight and previous/next week controls. Open any day; its title, exercise tabs and + picker belong to that date. Back goes to that day's week. Retain each day's selected exercise.
- Show one weight column. Put a compact lb/kg selection beside Weight; conversions retain canonical hundredths of a pound. Last (previous training day, date and top set) and PR (heaviest performed set, reps breaking ties) are distinct banners below the exercise title. Their source entries open as editable days. No Common banner.
- New exercises begin with one blank, unperformed row. New set appends a blank row and focuses Weight (Reps for bodyweight). No default zero-load batches. Required values are weight and reps for weighted exercises, reps alone for bodyweight; an explicitly entered zero is valid weight.
- Input changes save recovery immediately. A row commits when Done, another row, another exercise, navigation, or backgrounding ends editing. Moving Weight → Reps within the same row does not commit it. Valid changes upsert only that set; incomplete new rows stay unperformed. Finishing an incomplete edit to an existing set removes that performed row but preserves its editable input. While editing, the last committed history remains unchanged.
- An interrupted active row reopens as an edit; abrupt termination does not silently commit it. Background callbacks finish editing normally. Week totals and Last/PR read committed history only.
- Keep the active row above the keyboard. The low numeric editor supports Next, Done, minus/plus and the existing finger ruler. Keyboard entry replaces ruler scrolling; a small keyboard/ruler mode button keeps both input methods available. Field tokens reject callbacks from an old row/field/unit.
- Repeat copies the immediately preceding complete row and records the new individual set immediately. It never copies a whole session. Hide Repeat if the last row is incomplete. Repeated values are legitimate; action IDs protect repeated delivery. Undo after repeat removes that new set. Undo after delete restores the original row, position and set identity. Later commits clear the older undo action rather than overwriting unrelated changes.
- Picker: seven muscle groups and separate All/Barbell/Dumbbell/Cable/Machine/Bodyweight/Other equipment filters. Search crosses groups while respecting equipment. Flat exercise rows show Added; Create exercise is a secondary action and captures name, group and equipment. Existing unclassified custom exercises remain searchable under Full body / Other.

### Builder-check decisions

- Undated legacy unfinished sessions go on the migration day's workspace, including removed-tab sessions; they remain unperformed. Existing performed entries retain their original dates.
- An existing row finished with incomplete input is unrecorded. Its UI row ID and raw input remain stable; completing it later creates a fresh performed-set/action identity. Ordinary valid corrections preserve performed IDs. Undo is offered for explicit repeat/delete, not unfinished typing.
- The builder check found no other important unanswered choices.

## Persistence and migration

- `TrainingDay` is a validated Gregorian YYYY-MM-DD key derived using the user's calendar time zone, with noon-based day/week arithmetic for DST safety. Persist explicit day membership so subsequent time-zone changes do not move existing sets between days.
- `TrainingWorkspace` holds visible week, route/day selection, preferred unit, day workspaces, row input/references, active field token and a targeted undo receipt. Each `TrainingRow` has a stable UI ID, raw weight/reps, unit and canonical-weight cache/dirty flag, plus optional performed-set ID. Empty/invalid text is recoverable and never fabricated into history.
- New performed rows use one-set Journal batches. Existing multi-set batches remain intact. Journal row commands find, correct, remove and restore individual sets while retaining surviving IDs, validating revisions and preserving consumed action receipts.
- Extend `JournalSnapshot` with optional training workspace. Format 4 writes history, custom library, legacy recovery (when present) and training state atomically. An explicit notebook-enabled flag distinguishes legacy snapshots from missing/corrupt notebook data. Read formats 1–3 unchanged; no rewriting during repository load. Journal-only convenience saves retain all metadata.
- Build day workspaces from existing performed sets, preserving their IDs and ordering. Keep legacy unfinished drafts unrecorded, including partial numeric input and removed-tab sessions. Unknown legacy exercise IDs remain represented without deleting their history.
- Legacy open per-set editors and pending recorded corrections are resolved in a one-time recovered-entry editor, reusing the existing validated Done/Cancel behavior before weekly migration. It never shows a Record button. Save the resolved original snapshot first, then rebuild the weekly model; cancel discards only that pending correction/editor. Preserve other unfinished sessions. This avoids silently committing or discarding old partial group corrections.
- A failed committed write publishes neither new history nor updated totals. Failed recovery writes keep the raw input open and show retry feedback. No cloud, backend or network dependency.

## Implementation plan

**Goal:** Ship the confirmed weekly notebook flow and the latest banner/unit changes in the native app and live preview.

**Architecture:** Pure domain commands and Codable workspace values; atomic snapshot persistence; main-actor application model; small SwiftUI week/day/picker/input components. Retain the old logger for compatibility and migration review, not as an alternate production flow.

**Tech stack:** Existing Swift 6 package, SwiftUI iOS 17+/macOS 14+, Foundation, local JSON repository, Swift Testing and XCTest.

**Spec:** Confirmed requirements and decisions above; original attachment `/Users/jaesong/.codex/attachments/383f74ba-4ef9-40d4-a473-0c21043fc0f4/Pasted text.txt`.

### Task 1 — Domain dates, exercise classification and row commands

Files: new `TrainingDay.swift`, `ExerciseClassification.swift`, `TrainingWorkspace.swift`, `JournalRows.swift`; extend `Models.swift` / `ExerciseLibrary.swift`. Tests: new `TrainingDomainTests.swift`.

- [x] Write and run failing tests for Monday weeks/DST, required bodyweight versus weighted values, unchanged kg conversion, row correction/removal/restore identity, duplicate delivery, and targeted undo with unrelated entries retained.
- [x] Implement `TrainingDay`, `MuscleGroup`, `ExerciseEquipment`, exercise effective metadata, `TrainingRow` / `DayWorkout` / `TrainingFocus` / `TrainingUndo` / `TrainingWorkspace`; validate row references and completeness independently of raw recovery text.
- [x] Add `Journal.reference(to:)`, `updateSet`, `removeSet` and `restoreSet` commands; retain batch/action/set invariants and limit restoration to the matching deletion revision.
- [x] Run the full suite and commit.

### Task 2 — Atomic format-4 persistence and legacy recovery

Files: `EntryWorkspace.swift`, repository adapters, new `TrainingMigration.swift`, `LegacyRecoveryModel.swift`; metadata retention in `LoggerModel`. Tests: `TrainingMigrationTests.swift`, `TrainingStorageTests.swift`.

- [x] Write/run failing tests for v1–v3 migration, partial draft retention, pending-editor resolution, unknown IDs, custom metadata defaults, missing enabled notebook state, failed writes and journal-only metadata preservation.
- [x] Add optional `JournalSnapshot.training`, format-4 enabled marker, and atomic save/load validation. Build explicit day assignments and retain unresolved original workspace until recovery review completes.
- [x] Implement one-time legacy review using existing set-editor commands and a memory snapshot adapter; never auto-record old drafts or apply old corrections on load.
- [x] Run full tests and commit.

### Task 3 — Weekly application model

Files: new `TrainingNotebookModel.swift`, focused command/projection extensions; tests `TrainingNotebookTests.swift`.

- [x] Write/run failing tests for valid-on-finish logging, incomplete recovery, no-op corrections, day isolation and totals, tab selection, new/repeat, undo repeat/delete, unit switching, failed commits, Last/PR committed-only projections and reopening.
- [x] Implement repository-backed `TrainingNotebookModel` with candidate transactions, focus-token input updates, complete-row finalization, day/exercise navigation, grouped picker metadata and summary projections.
- [x] Run full tests and commit.

### Task 4 — Native weekly UI and live preview

Files: new week/day/banner/set-row/numeric/picker views; `App/SendaApp.swift`, preview renderer, minimal legacy editor callbacks.

- [x] Build Week → Day flow, separate Last/PR, one weight column and header switch, flat filtered picker, blank/new/repeat rows, subtle saved status and targeted Undo.
- [x] Wire app lifecycle, recovered-editor gate and sample/real local composition. Keep active input visible and reject old focus callbacks. Remove recording buttons from reachable production UI.
- [x] Render week, day, picker and compact states from actual SwiftUI; inspect layout and update the running local preview and committed previews.
- [x] Run unit suite and host typechecks; commit.

### Task 5 — iPhone behavior checks and final review

Files: update existing `Tests/SendaUITests/LoggerUITests.swift` to the new production flow, README, implementation notes.

- [x] Cover week/day navigation, weighted/bodyweight entry, finish boundary, partial recovery, repeat/delete undo, unit precision, Last/PR, grouped/custom picker and large text.
- [ ] Run full local tests and both phone workflows; request a fresh whole-change review, fix confirmed material issues with regression tests, and push the finished branch.

## Review focus

1. A row or source entry belongs to a different day/exercise: edits must not affect today's rows or another set.
2. Empty/trailing-decimal input at navigation/reopen: preserve it without creating a performed zero or default set.
3. Duplicate actions and undo after another change: preserve unrelated sets and consumed action IDs.
4. Rounded kg display and stale native field callbacks: retain exact canonical load and ignore old focus tokens.
5. Legacy open group corrections and failed migration/write: leave original data intact and recoverable.
