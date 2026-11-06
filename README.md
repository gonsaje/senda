# Senda

A native iPhone training notebook for the moment between sets. One editable line becomes one recorded entry in place. No workout setup, account, network service, or cloud dependency.

## Run on iPhone

1. Install full Xcode 16 or later with an iOS simulator runtime.
2. Open **Senda.xcodeproj**, choose an iPhone simulator, and run the **Senda Sample** scheme to explore the notebook with prior performed entries. Sample changes stay in memory and disappear on relaunch.
3. Use the **Senda** scheme for an empty real journal with local persistence. For a physical iPhone, select your development team in Signing & Capabilities and use a unique bundle identifier if needed.

Minimum device version: iOS 17. No third-party dependencies or project-generation step.

## Try the central flow

- Choose Bench, DL, or Squat from the lift index. Each lift keeps its draft during the current session.
- The small **Last** line is performed history. The large **DRAFT · NOT RECORDED** line is a suggestion until you record it.
- Tap weight, reps, or sets to select the low numeric control. Use common values, minus/plus, or tap the dock number to type. Typed digits stay buffered until Done, a field change, or Record. Cancel discards the typed edit. Invalid input must be corrected or cancelled before leaving it.
- **One set different?** opens a separate edit buffer. Change set 4 from 10 to 8 and choose **Keep draft changes**. The journal now shows the ordered reps; nothing has been written to history. Tap the small set-count control to change batch size even with exceptions.
- **Record 4 sets** writes all four ordered sets together. The same journal line now says **RECORDED**.
- **Edit sets** has an explicit Save corrections / Cancel boundary. **Undo** removes the visible batch, including its corrections, and returns those values to a fresh draft.
- **Another batch** creates a new record action. Identical values are allowed. Repeated delivery of the same action is protected independently of content.
- Expand **Compare last entry** after saving to see actual entries and a factual rep difference when every set uses the same load.

## Tests and sample

```sh
bash scripts/test.sh
swift run senda-sample
```

The test script uses Swift Testing and also supports this machine's standalone Command Line Tools installation. When running inside a restricted build environment, pass writable cache locations and `--disable-sandbox` as needed. In Xcode, open `Package.swift` to run the package tests; the application schemes launch the app and do not contain separate test targets.

The suite covers complete-batch validation, individual ordered sets, fractional loads, duplicate actions versus intentional identical batches, revisions, targeted undo, retained action receipts after reopening, file-write failures, corrupt/future journal formats, draft isolation, per-set confirm/cancel, lift switching, buffered keyboard edits, and committed-only comparisons.

## Structure

| Module | Responsibility |
| --- | --- |
| `SendaDomain` | Pure value models, validated journal commands, action receipts, comparisons, sample entries |
| `SendaPersistence` | Main-actor repository boundary; memory and versioned atomic JSON adapters |
| `SendaLogger` | Observable screen state, per-lift sessions, numeric input buffer, edit boundaries |
| `SendaNotebook` | SwiftUI notebook, thumb dock, set editor, comparison |
| `App` | iPhone entry point and local/sample composition |

The real journal lives in the app's Application Support directory at `Senda/journal-v1.json`. A command produces a complete candidate, the adapter writes it, then the model publishes it. A failed write does not publish the candidate. The file adapter uses Foundation's [atomic write option](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) to replace the file as one operation. Unreadable files are preserved and opening fails visibly; there is no silent empty-store fallback.

Weights are integer hundredths of a pound. Individual performed sets have stable IDs and 1-based positions; corrections retain existing IDs. Action receipts remain consumed after undo and persist with history. Revision checks reject stale corrections/undo. The app has one main-actor writer; multi-process or concurrent writers are outside this MVP.

## Visual review

Ivory `#F7F3EB`, terracotta `#A94E32`, charcoal `#302720`, system serif headings, and tabular numerals. The original canonical logo attachment is not available in this workspace, so the small typographic wordmark is temporary.

`docs/previews/` contains actual SwiftUI **macOS-hosted renders at phone dimensions**, not iPhone simulator screenshots. Regenerate on macOS with:

```sh
swift run senda-preview "$PWD/docs/previews"
```

## Validation limits and deliberate scope

Swift package builds, the domain sample, unit tests, and host SwiftUI renders can run without Xcode. This development machine lacks full Xcode and the iOS SDK, so iPhone build/signing, keyboard-open layout, VoiceOver, large Dynamic Type, app relaunch persistence, and touch interactions still require simulator/device validation. The app entry is typechecked against the available macOS SDK; that is not an iOS build.

Recorded data persists in the normal scheme. In-session drafts, typed buffers, the selected recorded line, and undo availability do not recover across app restarts. A fresh session suggests the latest performed values in a new unrecorded draft. There is no full history browser, custom exercise catalog, kg conversion, sync, backend, or global undo stack in this focused MVP.

The prior planning and architecture documents remain untouched. This workspace began empty; the new implementation note records the recovered requirements and implementation choices without replacing the approved report.
