# Profile Refinement Implementation Plan

**Goal:** Give Profile one clear route to each task and make its sheets easier to use at compact and Larger Text sizes.

**Architecture:** Refine the existing three Profile views. Give TrainingSettingsView an explicit weightUnits/backup destination, reuse the existing model actions and leave NotebookBackupTools and all persistence unchanged.

**Tech stack:** SwiftUI, existing Senda modules, Swift Testing and native XCTest.

**Spec:** `docs/superpowers/specs/2026-11-10-profile-refinement.md`.

## Constraints and review focus

Keep the established palette, Georgia headings, flat rows and 44-point targets. Preserve invalid/raw name input, save errors, unit retry, unfinished workouts and all backup warnings/confirmation/recovery. Check long names, keyboard-visible actions, selected-unit traits, compact header wrapping and return paths. Shared dock behavior is outside this pass.

## Cohesive task: Profile destinations and forms

**Files:** TrainingProfileView.swift (three rows), ProfileDetailsView.swift (pinned actions and shared submit), TrainingSettingsView.swift (focused/adaptive sheets), Preview.swift (focused fixtures), LoggerUITests.swift (interaction checks), README.md (updated navigation), this spec and plan.

- [x] Read guidance and independently audit the existing Profile; capture fresh native and rendered baseline.
- [x] Add `testProfileFocusedUnitsAndNameSubmit` before product edits. Baseline fails at the assertion that the units sheet should not expose export-backup, confirming the current full Settings route.
- [x] Replace Profile's duplicate gear route with Name, Weight units and Backup & restore rows. Use 16-point section spacing and 12-point row padding.
- [x] Give TrainingSettingsView.Destination cases weightUnits and backup. Render only that destination, retaining immediate unit saves and all backup tools; adapt the title/Done header with ViewThatFits.
- [x] Pin name Cancel/Done; put the field first, and share the Done/Return save path. Retain raw input and errors on failure.
- [x] Add compact Largest Text checks; update old gear-driven checks to use the visible units row. Pass full semantic suite and focused submit/cancel/error/recovery/backup checks.
- [x] Inspect fresh Profile/name/units/backup/restore-review states and obtain independent final review.
- [x] Apply only eight baseline-checked files, verify hashes/whitespace and save review artifacts. No commit or push.

Use interaction tests for changed behavior and visual checks for spacing/copy, rather than tests that mirror styling. Artifacts live in the review workspace under `output/profile-refinement`.

## Verification

The full semantic suite passes 455 tests in 57 suites. Native iPhone 16 checks pass for the focused units destination and selected state, immediate unit persistence, Return-to-save for a valid name, cancelling an unsaved change, invalid-name raw-text/error recovery, all backup actions and the no-pre-restore-copy status. The existing unfinished-workout/profile recovery case also passes after editing a name, changing units, visiting Learn and relaunching.

The compact iPhone 13 mini passes the same focused name/units flow. At the largest text setting, the new case verifies reachable name Cancel/Done while typing (minimum 44 points), selected kilograms, visible sheet Done controls, the adaptive backup header, the fully visible restore action and return to Profile. Its initial run exhausted the shared helper's twenty 90-point drags before Restore. Independent video review confirmed steady scrolling through the backup explanations; another 693 points was needed. This test now uses bounded page-sized gestures within the actual sheet and retains hittability plus full vertical bounds assertions. It passes in 34.0 seconds. No product or backup-copy workaround was needed.

Fresh renders cover empty, named, maximum-length name, kilograms, compact, Larger Text, name form, focused units, direct backup and restore-review states. Independent source/visual review found no actionable issues; follow-up review confirmed the test gesture change preserves and strengthens visibility assertions.

Applied eight focused files after destination baseline checks, with destination hashes and whitespace verified. NotebookBackupTools, ProfileModel, TrainingNotebookModel, persistence, other screens, shared dock and branding remain unchanged. The shared dock's existing Largest Text label wrapping remains outside this pass. Review artifacts, source backups, patch and application manifest are in the review workspace under output/profile-refinement. No commit or push.
