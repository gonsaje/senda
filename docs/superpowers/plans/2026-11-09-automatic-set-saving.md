# Automatic Set Saving Implementation Plan

**Goal:** Save valid set changes on user updates and remove the recording-state UX.

**Architecture:** Reuse the atomic local snapshot transaction. Synchronize the focused valid set while preserving raw input and identity; normalize only when closing the editor. Keep incomplete text and failure recovery separate from valid journal values.

**Tech stack:** Swift 6, SwiftUI, Swift Testing, existing local JSON repository.

**Spec:** `docs/superpowers/specs/2026-11-09-automatic-set-saving.md`.

- [x] Add failing behavior tests for immediate saving, raw text, identity, historical precision, partial input and retry supersession.
- [x] Extract focused-set synchronization and apply it before atomic persistence; retain a raw recovery snapshot on numeric save failure.
- [x] Update existing tests whose assumptions depended on Done accepting a complete row. Preserve incomplete-input and failure guarantees.
- [x] Remove row status labels and manual-recording language; update iOS UI acceptance assertions and source-parse them.
- [x] Review native normal, compact, Larger Text, partial correction and save-failure screens. Run the package suite and inspect any failure before applying.
- [x] Check original active-file hashes, apply only reviewed files, rerun actual-package verification and refresh the local preview.
