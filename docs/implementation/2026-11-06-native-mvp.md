# Senda native logger MVP

This is a new implementation note, not a replacement for the approved Plan v3 or architecture report. The workspace was empty. The referenced chat supplied the notebook requirements and confirmed that sets are canonical; the original report and image attachments are not present locally and have not been modified or recreated.

## Scope and decisions

Build the approved single notebook surface in SwiftUI for iOS 17+. Keep recent lift names, quiet performed history, one dominant draft sentence, a low numeric dock, explicit recording, and in-place recorded state. Use ivory `#F7F3EB`, terracotta `#A94E32`, charcoal `#302720`, system expressive serif type and tabular numerals. Use a temporary typographic Senda wordmark until the canonical original logo file is available; do not fabricate a replacement logo.

Use a dependency-free Swift package split into domain, persistence, logger state, and SwiftUI views, plus a checked-in Xcode iPhone application. A pure value domain and a versioned, atomic JSON adapter keep the storage choice replaceable. SwiftData would add framework coupling without helping this small single-writer local journal. No cloud, accounts, custom outbox, networking, or sync authority is selected.

Weights use integer hundredths of a pound. A batch owns individual ordered sets. Validate the entire candidate before committing. A commit action UUID protects against repeated delivery; identical values with a new UUID are legitimate. Keep consumed UUID receipts after undo. Corrections replace a batch atomically with a revision check and preserve set identity where possible. Undo removes exactly the visible batch, including its corrections, and returns those values to a new, unrecorded draft. Undo is available while that batch is visible; it is not a global undo stack.

Drafts and per-set edit buffers are separate from performed history. Confirming draft exceptions only changes the draft. Confirming recorded edits persists them; cancel does neither. Switching lifts preserves each lift's in-session draft/recorded state. Draft recovery across app restarts is intentionally outside this MVP. Recorded entries and action receipts persist. A separate in-memory sample mode prevents demo records from mixing with a real journal. Comparison only uses committed batches of the same lift, and reports rep differences only when the loads match.

## Implementation plan

1. **Domain:** write failing tests for validation/atomicity, ordered exceptions, UUID idempotence, identical new batches, consumed undo receipts, revision conflicts, and factual comparison. Implement value models and journal commands. Run the complete suite.
2. **Persistence:** test real temporary-file round trips, atomic failure behavior, unsupported/corrupt files, and receipt retention after reload. Implement `JournalRepository` and the versioned JSON adapter. No fallback that overwrites unreadable history.
3. **Logger state:** test draft/committed separation, edit confirm/cancel, failed saves/undo, per-lift state, another batch, and comparisons after correction. Implement an observable main-actor model shared by the app and tests.
4. **Native surface:** compose focused SwiftUI notebook, numeric dock, and per-set editor views. Create the iPhone project, isolated sample scheme, launch instructions, and a runnable command-line domain demonstration. Compile all package targets and run all tests. Validate Xcode project structure. Full iPhone build/render awaits an installed Xcode and iOS SDK.

## Review focus

- Invalid or partially typed numbers must never enter history.
- A failed file write must leave history and the visible draft unchanged.
- Replayed actions must stay consumed across undo and restart.
- Lift switching and cancelled edits must not silently lose draft exceptions.
- Narrow screens, large type, and a keyboard must retain access to the save action; verify on a simulator/device when Xcode is available.

## Execution record

- Proceeding with the user's explicit native MVP implementation request and already approved notebook direction; no new design approval gate.
- Empty workspace, no Git repository or existing branch to isolate. Working in the supplied directory.
- Swift 6.3.3 is installed. Only Command Line Tools are installed; `xcodebuild` and `simctl` are unavailable.
- Domain/persistence RED→GREEN: 12 tests; logger state RED→GREEN: 21 tests; sample-data check brought the suite to 22. Additional validation coverage brought it to 24.
- Fresh read-only review identified intermediate keyboard digits truncating exception sets and a missing set-count selector for mixed reps. Reproduced the input defects in failing tests. Moved keyboard buffering into the tested logger model; complete valid values apply once at an explicit boundary. Mixed-rep drafts retain a tappable set-count control.
- Added exact future-format detection before decoding a potentially incompatible journal payload, with a failing-then-passing regression test.
- Ruling: invalid typed input blocks field/lift changes until corrected or cancelled, so no intermediate value can become an unintended draft. Cancel is directly available in the thumb dock.
- Host compiler workaround: use an explicit closure for the main-actor text binding; passing the isolated method directly triggers a Swift 6.3.3 IR-generation crash. No application behavior depends on that workaround.
- The fresh reviewer found no critical defects. iPhone keyboard, Dynamic Type, VoiceOver, and device persistence remain unverified because Xcode/iOS SDK are absent. Host previews are explicitly macOS renderings at phone dimensions.
- Final verification: 28 tests in 4 suites pass; every package target compiles against the host SDK. The app entry typechecks on macOS. The command-line sample verifies ordered exceptions, replay protection, factual comparison, and undo. The Xcode project and both schemes parse and have valid object references. Three actual host SwiftUI previews are rendered and visually inspected. No iOS build or simulator result is claimed.
