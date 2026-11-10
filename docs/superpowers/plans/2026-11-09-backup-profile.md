# Backup and profile implementation plan

> For agentic workers: implement the scoped tasks in parallel where file ownership is independent, then perform whole-change review and verification.

**Goal:** Complete local backup ownership and clear on-device profile language.
**Architecture:** Pure archive/CSV codec; durable two-file restore store; model/session adapters; shared SwiftUI import preview/export tools.
**Tech stack:** Swift6, SwiftUI, Foundation, Swift Testing, iOS17/macOS14.
**Spec:** docs/superpowers/specs/2026-11-09-backup-profile.md

## Global constraints
Preserve exact canonical data, unfinished corrections, IDs, custom/hidden exercises, and local dates. JSON backups require an openable training workspace and format senda-backup/version1. Imports are capped at50MiB. No third-party dependencies, sync, merge, commits or live personal-data replacement.

## Review focus
- Crash between journal/profile writes: pending marker rolls back before opening.
- Original files absent/corrupt: retain raw bytes or absence accurately.
- Stale failed logging retry: successful restore clears unpublished old actions.
- Incomplete corrections/hidden rows: exact roundtrip and no accidental finalization.
- Canceled file picker and invalid import: no restore write or false success.

## Tasks
- [x] Codec: NotebookBackupCodec.swift + real roundtrip/invalid/CSV tests. Prove RED then focused GREEN.
- [x] Restore store: NotebookRestoreStore.swift + real temporary-file failure/startup/recovery-copy tests. Prove RED then focused GREEN.
- [x] Model/session: archive exports, restore adaptation, error state and name-only profile save, with workflow regressions; wire file store into App/live preview before opening models.
- [x] UI: truthful Profile/details, Settings units/storage, system exporters/importer, preview and explicit replacement confirmation, saved recovery copy and opening-error tools.
- [x] Integration: direct Persistence dependency, native preview fixtures and gallery, iPhone UI source updates, README/implementation evidence.
- [x] Verify: complete test suite, native full/compact renders, independent review, guarded apply and applied-app verification.

No commit or PR step: existing user changes remain uncommitted and unrelated files are preserved.
