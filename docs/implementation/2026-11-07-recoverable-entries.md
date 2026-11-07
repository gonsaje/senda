# Recoverable entries and simpler editing

The user requests recovery after reopening and a fast, minimal logger that feels editable rather than organized around drafts. Preserve earlier planning/architecture documents; this note describes the new implementation only.

## Product decisions

- Keep one notebook page with a row for each set (weight and reps) and the current ivory, terracotta, charcoal, serif, and tabular-number language. Remove DRAFT/RECORDED eyebrows, redundant Training heading, saved-device banners, and explanatory captions. Labels for units and table columns remain.
- Before the first record, values are an unfinished entry. They recover silently but do not enter performed history. Keep the explicit Record N sets action so suggestions never become performance records.
- Recorded rows stay directly tappable. Tapping starts a correction in the same numeric dock; Done saves it, Cancel restores the recorded values. The user confirmed Done as the correction boundary. Add set appends a row; New entry starts another legitimate batch. Removing a row retains the surviving performed-set identities, including when the final values happen to be identical.
- The quiet previous-entry line is tappable to edit its individual sets without overwriting the current unfinished entry. Per-set editing uses Cancel and Done, with no draft terminology.
- Reopen exactly where the user left off: selected lift and field, unfinished entries for every visited lift, partial/invalid numeric text, an open per-set editor and its raw inputs, a pending correction, or the recorded line. Recovery never records work or duplicates a batch. Undo remains targeted and recoverable.

- Show lb and kg together in every main row. Tapping either selects its unit for editing; the dock also exposes both unit buttons. The user refined the sliding scale into a scrolling ruler dial. It spans the full supported range from zero, with lazy tick rendering, precise stepping, and typed input available. The center marker follows the selected tick; programmatic positioning and unit switching never round untouched canonical weights. The previous-entry editor offers both unit choices and a visible alternate-unit value.

## Storage and boundaries

Use one version-2 atomic JSON snapshot containing the canonical Journal and an optional EntryWorkspace. This gives save, correction, undo, and recovery one consistent transaction; separate files would create a crash window. Read version-1 files without loss and upgrade on the next write. Keep the existing filename so installed journals are found. Unknown/corrupt formats remain untouched with a visible error.

Put Codable workspace value types and NumericField in SendaDomain (no SwiftUI or I/O), the snapshot repository in SendaPersistence, and behavior in SendaLogger. Preserve the existing pure performed-set commands and action receipts. The workspace validates references and revisions against the journal, bounds text buffers, and retains invalid text without letting it into history.

Write recovery through after each accepted interaction, plus an app-lifecycle flush. For this small single-writer MVP, immediate snapshot writes favor deterministic recovery; do not add cloud services, background queues, or two-file reconciliation. Measure this before introducing debouncing later. Recovery-write failure preserves in-memory edits and shows a quiet retry message. A failed performed-history save never publishes a candidate history.

## Implementation plan

1. Add failing recovery and editing tests before implementation. Move serializable workspace types into the domain and introduce the snapshot repository, keeping load/save journal convenience functions for existing callers.
2. Implement file migration, atomic combined snapshots, strict validation, and failure tests with actual temporary files. Do not overwrite unreadable history.
3. Restore and checkpoint logger state. Implement direct recorded-number corrections, Done/Cancel, previous-entry editing, and recoverable raw per-set inputs. Keep progression committed-only and batch actions idempotent.
4. Simplify the native views and app lifecycle integration. Refresh actual SwiftUI previews. Update UI tests to assert controls and history values rather than status banners; add terminate/relaunch recovery and direct-correction flows.
5. Run the full unit suite, host typechecks and rendering, an independent review, then the iPhone simulator workflow on a development branch when publication is permitted. Leave main unchanged.

## Review focus

- Recording, correcting, and undoing persist their matching workspace in the same atomic write.
- Partial numeric text and per-set edits reopen intact without falsifying progress.
- Done and Cancel distinguish local changes from performed history without status banners.
- Editing an older reference does not discard the current entry; stale revisions are rejected.
- Recovery write errors are visible and retryable; corrupted/version-1 files never silently reset.

The first iPhone run caught a view-level recovery regression: automatic scroll-position updates on reopening could replace partial keyboard text with a nearby dial tick. The ruler now treats scroll position as display state only. An explicit drag (including its predicted release motion) or accessibility adjustment changes weight; layout never writes it. The same direct drag works in the Mac preview. Screenshot hosts are detached and closed after rendering so hidden examples do not remain subscribed to later state changes.
