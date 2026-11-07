# Senda

A native iPhone training notebook for the moment between sets. Each set has its own weight and reps row, with lb and kg visible together. No workout setup, account, network service, or cloud dependency.

## Run on iPhone

1. Install full Xcode 16 or later with an iOS simulator runtime.
2. Open **Senda.xcodeproj**, choose an iPhone simulator, and run the **Senda Sample** scheme to explore the notebook with prior performed entries. Sample changes stay in memory and disappear on relaunch.
3. Use the **Senda** scheme for a real journal with local persistence and automatic recovery. For a physical iPhone, select your development team in Signing & Capabilities and use a unique bundle identifier if needed.

Minimum device version: iOS 17. No third-party dependencies or project-generation step.

## Try the central flow

- Choose Bench, DL, or Squat from the lift index. The quiet **Last** line references performed history; tapping it opens that previous entry for correction.
- Every set shows **lb**, **kg**, and **reps**. Tap either weight value to edit in that unit. The low dock has both unit choices, a scrolling ruler dial, minus/plus, and direct number entry. Drag the ruler horizontally with a finger (or mouse in the Mac preview); a faster release carries it farther. The dial spans zero through the full supported range (10,000 lb / 4,535.9237 kg), with 2.5 lb / 1.25 kg tick steps; typing accepts finer amounts. Switching units alone preserves the exact stored weight.
- Edit one row without changing the others. **Add set** copies the last row; the minus beside a row removes it. For example, change set 4 from 10 reps to 8 before recording.
- **Record 4 sets** writes all four ordered sets together. Unfinished numbers recover automatically after reopening, including incomplete input, without being counted as performed work.
- Logged rows remain directly editable. **Done** saves the correction; **Cancel** restores the recorded entry. Corrections and open previous-entry editors also recover after reopening.
- **Undo** removes the visible entry, including corrections, and leaves its values ready to record again. **New entry** starts a fresh action; intentional identical entries are allowed, while repeated delivery of the same action is protected.
- Expand **Compare last entry** after recording to see actual entries and a factual rep difference when every set uses the same load. Unfinished changes do not affect progress.

## Tests and sample

```sh
bash scripts/test.sh
swift run senda-sample
```

The unit test script uses Swift Testing and supports standalone Command Line Tools. In a restricted build environment, pass writable cache locations and `--disable-sandbox` as needed. In Xcode, open `Package.swift` to run package unit tests. Both application schemes include the `SendaUITests` interaction tests, which run with ⌘U on an iPhone simulator.

With full Xcode installed, run the app build and iPhone interaction tests from Terminal:

```sh
bash scripts/test-ios.sh
# Optional compact phone:
SENDA_SIMULATOR_NAME='iPhone 13 mini' bash scripts/test-ios.sh
```

The script chooses an installed iOS runtime supported by the selected Xcode, creates a temporary simulator, and deletes only that simulator afterward. Set `SENDA_SIMULATOR_ID` to use an existing simulator instead. Results and screenshots go in ignored `TestResults/`; `SENDA_TEST_RESULTS` overrides that location. Debug persistence tests use separate UUID-named journals without touching a person's journal.

The `iPhone validation` GitHub workflow runs unit tests plus iPhone 16 and iPhone 13 mini UI checks on Xcode 16.4. Test result bundles are retained for seven days. It does not deploy or add a service to the app.

Unit coverage includes atomic batches and snapshots, duplicate actions versus intentional identical entries, ordered set identities through add/remove/correction, targeted undo, version-1 migration, corrupt/future files, failed writes, raw input recovery, per-lift state, Done/Cancel corrections, independent previous-entry editing, row-specific edits, lb/kg conversion and rounding, full-range dial values, and committed-only comparisons. UI coverage includes row editing, simultaneous units and switching, scrolling weights, keyboard-visible recording, correction/undo, intentional identical entries, relaunch recovery, and action reachability with large text.

## Structure

| Module | Responsibility |
| --- | --- |
| `SendaDomain` | Pure value models, journal commands, action receipts, weight conversion, recoverable workspace values, comparisons |
| `SendaPersistence` | Main-actor snapshot repository; memory and versioned atomic JSON adapters |
| `SendaLogger` | Observable screen state, per-lift sessions, row/unit selection, buffered input, editing and recovery |
| `SendaNotebook` | SwiftUI set rows, thumb dock, weight dial, previous-entry editor, comparison |
| `App` | iPhone entry point, lifecycle recovery flush, local/sample composition |

The real journal remains at Application Support `Senda/journal-v1.json` so existing installations retain their data. The version-2 file contains the performed journal and optional recoverable workspace in one snapshot. Version-1 journals load without rewriting and upgrade on the next write. Recovery writes follow each accepted interaction. Record, correction, and undo write their candidate history and matching workspace together, then publish the result. A failed history write leaves committed history unchanged; a recovery-write error retains open edits and offers retry. Unreadable files remain untouched and fail visibly.

Weights remain integer hundredths of a pound; kg uses the exact conversion factor 0.45359237. Only explicit weight edits round back to that canonical precision. Display conversion and unit switching never rewrite untouched weights. Performed sets have stable IDs and 1-based positions; removing a row preserves surviving IDs, and new rows receive new IDs. Action receipts remain consumed after undo. Revision checks reject stale corrections/undo. The app has one main-actor writer; multi-process writers are outside this MVP.

## Local preview

Ivory `#F7F3EB`, terracotta `#A94E32`, charcoal `#302720`, expressive serif headings, and tabular numerals. The original canonical logo attachment is unavailable in this workspace, so the small typographic wordmark is temporary.

```sh
python3 scripts/preview.py
```

Open **http://127.0.0.1:8765** for actual SwiftUI renders that refresh as source changes. Interact with controls in the **Senda — Live preview** Mac window. That window uses its own sample journal in `/tmp/senda-live-preview/`, separate from the iPhone journal. Stop the watcher with Ctrl-C. The browser review serves only preview files on this Mac.

`docs/previews/` contains actual **macOS-hosted SwiftUI renders at phone dimensions**, not iPhone simulator screenshots. Regenerate on macOS with:

```sh
swift run senda-preview "$PWD/docs/previews"
```

## Validation limits and scope

Swift package builds, the domain sample, unit tests, and host SwiftUI renders run without Xcode. This machine lacks full Xcode and the iOS SDK, so iPhone builds and interaction tests require the GitHub workflow or another Xcode installation. Host typechecking does not establish an iOS build. Physical-device signing, VoiceOver, and keyboard ergonomics still need device testing.

The normal scheme persists performed entries and recoverable unfinished work. The sample scheme remains memory-only. There is no cloud, sync, backend, full history browser, custom exercise catalog, or global undo stack.

Prior planning and architecture documents remain untouched. Implementation notes record the changes without replacing the approved report.
