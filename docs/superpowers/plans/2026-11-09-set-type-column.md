# Set Type Column Implementation Plan

**Goal:** Put set type in a prominent, independently editable column and support Regular, Warm-up, Working set and Drop set.

**Architecture:** Add stored types and one shared plan-counting property. Reuse atomic metadata mutation for immediate type choices. Preserve legacy values and protect the next-workout comparison from drop-set sessions. Version local and backup writers for the expanded enum.

**Tech stack:** Swift 6, SwiftUI, Swift Testing, existing local persistence.

**Spec:** `docs/superpowers/specs/2026-11-09-set-type-column.md`.

- [x] Add failing tests for the Regular default, type round trips, plan counts and Drop-set guidance rules.
- [x] Implement enum/default/guidance changes and writer versions with older-reader coverage.
- [x] Add the Type column/button and immediate selection sheet, keeping Reps left separate and layouts accessible.
- [x] Run the integrated package suite, source-parse iOS acceptance tests and review actual native normal/compact/Larger Text/type-choice/failure renders.
- [x] Apply only reviewed files after checking active source hashes; verify the applied package and refresh the preview.
