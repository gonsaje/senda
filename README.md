# Senda

A native iPhone training notebook. Browse a week, open a day, and enter individual sets. The app saves locally; no account, network service, backend or cloud dependency.

## Run

1. Open **Senda.xcodeproj** in Xcode 16.4 or later with an iOS 17+ simulator.
2. Run **Senda Sample** for a populated sample week. Sample changes stay in memory.
3. Run **Senda** for a real journal with automatic local persistence and recovery. Physical-device builds need your development team and signing configuration.

The project has no third-party dependencies or generation step.

## App sections

A minimal bottom dock has **Log**, **Learn**, and **Profile**. Switching sections finishes a valid set or keeps incomplete input recoverable; failed saves retain the current section. Log returns to the selected day and exercise.

**Profile** has editable on-device name and optional email, default lb/kg settings, all logged exercise PRs and a Big 3 breakdown. The total adds the heaviest logged bench, deadlift and squat sets; reps break weight ties. A total appears only when all three lifts have records. This is a sum of observed sets, not an estimated one-rep max or competition result. Tap a PR to open its original set. Corrections, deletion and Undo update progress from the journal. Default units affect progress and new days, preserving existing day units and canonical weights.

Profile details use a separate versioned atomic local file. An unreadable profile stays untouched and does not prevent logging. There is no account authentication or synchronization.

**Learn** has searchable offline setup, movement and form cues for all 20 presets, with explicit links to original sources. Broad exercise names specify the variation covered. Custom exercises remain searchable and clearly show when a guide has not been added. [Source notes](docs/implementation/2026-11-08-form-sources.md).

## Notebook flow

- **Week → Day → Exercise.** A Monday–Sunday list shows each day's trained muscle groups and set count. Categories appear once, using only performed sets; opening the day shows the individual exercises and sets. Days without logged sets show **+ Start workout**; tap the row to open that day's workout, keeping any unfinished entries. Swipe left for the next week or right for the previous week; vertical scrolling and the arrow controls remain available. In the day view, arrows beside the date move to the previous or next calendar day; **‹ Week** returns to that day's week. Each day retains its own exercise tabs, selection and sets. Changing days finishes the current edit, preserving incomplete input without counting it.
- When a day has multiple exercises, **All N** in the exercise tab row opens the full day list. All and Add stay visible while the tabs scroll. Tabs have larger padded tap areas, a subtle shadow on the selected exercise, and quiet edge shadows wherever more tabs are offscreen. Each list row shows its actual logged-set count, or **No sets yet**. Select one to return to its existing sets, or choose **Add exercise** from the list.
- Use **+** to browse exercises by muscle group, narrow by equipment, or search across groups. Flat rows show **Added** when already in the day. **Create exercise** accepts a name, muscle group and equipment. Existing unclassified custom exercises remain searchable under Full body / Other.
- Each set has one weight value and reps. The compact **lb/kg menu beside the exercise name** changes the day's display unit without rounding untouched canonical values. **Last** and **PR** are separate banners. Last is the previous training day's top set; PR ranks performed weight first, then reps. Tap either to open its source day. There is no Common banner.
- A newly added exercise starts with a blank row. **New set** adds another blank row and focuses Weight, or Reps for bodyweight exercises. No zero-weight batch is prefilled.
- Tap a value to edit. **Next** moves Weight → Reps within the row. **Done**, another row, another exercise, navigation or backgrounding finishes the edit. A weighted set needs a weight and 1–999 reps; bodyweight needs reps alone. Explicit zero weight is allowed.
- A complete row counts when editing finishes. Incomplete rows are retained without counting. Existing performed values remain committed while editing; finishing an incomplete correction unrecords that set while retaining the editable row. Completing it later uses a fresh performed identity. Ordinary valid corrections retain set IDs.
- There is no Record button and no completion checkbox. Recovery saves accepted input immediately. An abruptly interrupted edit reopens with its partial input; it is not silently recorded on launch.
- The low numeric editor opens weight on a finger-draggable full-range dial, with Next, Done and minus/plus. Tap its large value to open the keyboard in the same editor; the ruler stays visible and never writes values merely because typed input moves its position. Dragging the ruler dismisses the keyboard. Reps open directly for typing. There is no keyboard/dial switch.
- **Repeat last set** copies only the immediately preceding complete row and counts the copy immediately. Identical values are legitimate. **Undo** after repeat removes that copy; Undo after delete restores the original row and set identity. New edits or navigation clear the older undo action.
- Each set has three vertical dots on its right edge. Tap them or swipe left to reveal a red X; swipe farther left and release to delete directly. Vertical scrolling and cancelled gestures never delete. Only one row stays open, and failed saves leave the row available for retry. **Undo** restores a deleted row in its original position.
- Hold an exercise tab to **Remove from day**. This hides the tab while retaining its rows and history. The week's totals still reflect actual performed sets.

## Local preview

```sh
python3 scripts/preview.py
```

Open **http://127.0.0.1:8765** for actual SwiftUI renders of Week, Day, Profile, Learn, exercise form and logger details. Use the **Senda — Live preview** Mac window for interactive controls. It has its own sample journal at `/tmp/senda-weekly-live-preview/journal.json`; the earlier preview journal is left intact. The browser serves only preview files on this Mac.

The visual language uses ivory `#F7F3EB`, terracotta `#A94E32`, charcoal `#302720`, expressive serif titles and aligned tabular numerals. Georgia headings pair with system text and tabular numerals. An original tapered S-path is drawn natively, with an editable SVG in `docs/brand/senda-path.svg`; muted olive marks the identity and quiet save feedback. The day header is compact, reference banners are neutral, and separators are lighter. New rows enter gently and successful repeats briefly highlight their new row. Reduced Motion disables positional transitions and animated focus scrolling. The canonical original logo attachment remains unavailable; this mark is a new drawing for review.

`docs/previews/` contains macOS-hosted SwiftUI renders at phone dimensions, not iPhone simulator screenshots. Regenerate with:

```sh
swift run senda-preview "$PWD/docs/previews"
```

## Tests

```sh
bash scripts/test.sh
swift run senda-sample
# Full Xcode and an installed iOS runtime:
bash scripts/test-ios.sh
SENDA_SIMULATOR_NAME='iPhone 13 mini' bash scripts/test-ios.sh
```

Unit tests use Swift Testing and work with standalone Mac Command Line Tools. Restricted environments can pass writable cache locations and `--disable-sandbox`. The iPhone script creates and removes only its own temporary simulator; `SENDA_SIMULATOR_ID` can use an existing simulator. Results are in ignored `TestResults/`, or `SENDA_TEST_RESULTS`. Both Xcode schemes include the interaction tests for ⌘U.

The GitHub **iPhone validation** workflow runs unit tests and interactions on iPhone 16 and iPhone 13 mini using Xcode 16.4. Debug UI tests use UUID-isolated journals. Result bundles are retained for seven days. The workflow does not deploy a service.

Coverage includes ordered batch/set identities, duplicate-action protection, automatic row boundaries, incomplete recovery, bodyweight requirements, day isolation and summaries, Last/PR projections, date/DST arithmetic, exact lb/kg conversion and unchanged-input echoes, repeat/delete undo, invalid workspace data, custom exercise classification, legacy editor recovery, migrations and failed atomic writes. iPhone flows cover navigation, entry, units, rapid typing, finger dial, recovery, source-day editing, grouped/custom picking, undo and large text.

## Architecture and data

| Module | Responsibility |
| --- | --- |
| `SendaDomain` | Journal commands and receipts, individual set operations, validated day/workspace values, classification and conversion |
| `SendaPersistence` | Main-actor snapshot repository; memory and versioned atomic JSON adapters |
| `SendaLogger` | Weekly application model, candidate transactions, projections and legacy recovery review; original logger retained for compatibility |
| `SendaNotebook` | Native week/day/picker views, set rows, banners, numeric input and recovered-entry UI |
| `App` | Real/sample composition, lifecycle finishing and local-file opening |

The real file stays at Application Support `Senda/journal-v1.json`. Format 4 stores the journal, custom library and weekly workspace in one atomic snapshot. An explicit enabled marker prevents a missing weekly workspace being mistaken for an empty journal. Formats 1–3 load without rewriting; the next accepted interaction writes the upgraded snapshot.

Performed IDs, original dates and consumed action receipts are preserved. Day membership is explicit, so time-zone changes do not relocate saved sets. Undated legacy unfinished sessions move to the migration day's workspace without being counted. Removed-tab sessions remain recoverable. A legacy open group editor or pending recorded correction gets a one-time Done/Cancel review before weekly migration. Input in that review is also recoverable. Old unfinished batches are never automatically recorded during migration.

Weights are integer hundredths of a pound. Kilograms use the exact factor 0.45359237. Display changes and unchanged input events preserve canonical values. New automatically logged rows use one-set batches; existing multi-set batches remain intact. Row commands preserve surviving IDs and reject stale undo/corrections. Failed committed writes publish neither history nor new totals; failed recovery writes retain input and offer retry. Unreadable files remain untouched and fail visibly. The MVP has one main-actor writer.

Approved planning and architecture documents remain unchanged. New implementation notes describe this revision without replacing them. There is no sync, backend, workout-template library or global undo stack. Physical-device signing, VoiceOver and keyboard ergonomics still require device testing; this Mac has Command Line Tools rather than full Xcode, so iPhone builds run through the workflow or another Xcode installation.
