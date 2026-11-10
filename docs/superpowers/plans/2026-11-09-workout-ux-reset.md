# Workout UX Reset Implementation Plan

**Goal:** Simplify the workout screen, use Working as the standard type, and implement one grouped Drop entry with saved weight/reps stages.

**Architecture:** Keep existing flat numeric rows and explicit optional group UUIDs; derive displayed entries and group-aware counts. Reuse atomic local snapshot persistence, adding batch-aware grouped removal/restore for reliable Undo. Keep the current brand while reducing header and row overhead.

**Spec:** `docs/superpowers/specs/2026-11-09-workout-ux-reset.md`.

- [x] Audit actual logging and secondary screens; preserve baseline renders and record priorities.
- [x] Test and implement Working defaults and legacy Regular presentation compatibility.
- [x] Repair workout hierarchy, compact rows and contextual effort editing without losing existing actions.
- [x] Test and implement explicit Drop groups, autosaved stages, counts, repeat/delete/Undo and compatibility versions/CSV.
- [x] Keep reference navigation visible and show grouped stages in saved history.
- [x] Run focused/full checks, review real normal/compact/Larger Text/failure renders and resolve findings.
- [x] Guard active-source hashes, apply only reviewed files, rerun the applied package and refresh the preview.
