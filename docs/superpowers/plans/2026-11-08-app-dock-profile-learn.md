# Senda App Dock, Profile and Learn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Log/Learn/Profile navigation, local profile details and settings, committed PRs and Big 3 breakdown, and exercise form guides.

**Architecture:** Keep journal and workspace format unchanged. Derive progress in the domain, coordinate section changes in the notebook model, and persist profile details through a separate repository. Compose small SwiftUI views around the existing logger.

**Tech Stack:** Swift 6, SwiftUI, Foundation, Swift Testing, XCTest; iOS 17 and macOS 14 minimums; no dependencies.

**Spec:** docs/superpowers/specs/2026-11-08-app-dock-profile-learn-design.md

## Global Constraints
- Preserve existing approved planning/architecture documents, exact canonical weights, set identity, recovery, correction and undo.
- Three dock items: Log, Learn, Profile. Navigation completes valid edits, retains incomplete rows and refuses transition after a failed journal write.
- Big 3 = heaviest logged bench + deadlift + squat; no invented total for missing lifts. PR weight ties use reps.
- Profile details stay local; an unreadable profile never overwrites itself or blocks the journal.
- All 20 presets have offline form cues and explicit primary-source links; custom exercises have an honest unavailable state.
- Use existing preview checkout on a new branch; preserve user .vscode/. No deployment or merge.

## Review Focus
- Unconfirmed high weights, failed saves, deleted records and undo must not create stale PRs or totals (Task 1 tests).
- Switching sections with partially typed numbers must preserve recovery without fabricating progress (Task 1 tests).
- Missing/zero-weight Big 3 components must not divide by zero or appear as completed totals (Task 1 and 4 checks).
- Profile read/write failure must retain bytes, user input and a usable Log (Task 2 tests).
- Small phones, large text and active keyboards must keep dock and editor controls reachable (Task 4 UI tests/native renders).

### Task 1: Committed progress and safe section navigation
**Files:** Create Sources/SendaDomain/TrainingProgress.swift, Sources/SendaLogger/TrainingSection.swift; modify Sources/SendaLogger/TrainingNotebookModel.swift. Add Tests/SendaDomainTests/TrainingProgressTests.swift and Tests/SendaLoggerTests/TrainingSectionTests.swift.
**Interfaces:** Journal.personalRecords -> [ExercisePersonalRecord]; Journal.bigThreeProgress -> BigThreeProgress; model.section, selectSection(_:), personalRecords, bigThreeProgress, setPreferredUnit(_:), openPersonalRecord(_:).
- [ ] Write failing tests for weight/reps ranking, all/custom records, missing/zero Big 3, correction/delete/undo, source navigation, section retention on failure and incomplete recovery.
- [ ] Observe failure before implementation, then implement the domain summaries and model commands using existing atomic commands.
- [ ] Run bash scripts/test.sh with the established /tmp build/cache paths. Expected: whole suite green.
- [ ] Commit the completed task with verification in the ledger.

### Task 2: Local profile details and persistence
**Files:** Create Sources/SendaDomain/ProfileDetails.swift, Sources/SendaPersistence/ProfileRepository.swift, Sources/SendaLogger/ProfileModel.swift; inject through TrainingNotebookModel, TrainingSession and App/SendaApp.swift. Add profile domain/persistence/model tests.
**Interfaces:** ProfileDetails(name:email:).validated(); ProfileRepository.load()/save(_:); FileProfileRepository(url:), MemoryProfileRepository; model.profile: ProfileModel; profile.details, openingError, errorMessage, reload(), save(name:email:).
- [ ] Write failing tests for trimmed valid details, invalid input, file roundtrip, unsupported/corrupt profile protection, failed write retaining old values, separate profile failure and reopened details.
- [ ] Implement versioned atomic profile adapter and guarded model; isolate UI-test profile paths and keep sample details in memory.
- [ ] Run the full local test command. Expected: all tests green and existing journal format unchanged.
- [ ] Commit and ledger evidence.

### Task 3: Offline exercise form library
**Files:** Create Sources/SendaDomain/ExerciseFormGuide.swift and Tests/SendaDomainTests/ExerciseFormGuideTests.swift; add docs/implementation/2026-11-08-form-sources.md.
**Interfaces:** ExerciseFormGuide.guide(for:), search(_:in:) with preset/custom exercise names; guide.setup, movement, cue, sourceTitle and sourceURL. Unknown/custom IDs return no guide.
- [ ] Write failing tests that cover every preset exactly once, exercise/muscle/equipment search, and unknown/custom IDs without invented guides.
- [ ] Verify primary sources and author concise original offline summaries for each preset.
- [ ] Run the whole suite. Expected: green; inspect source URLs and individual exercise variation matches.
- [ ] Commit with ledger evidence.

### Task 4: Dock and reviewable screens
**Files:** Modify TrainingNotebookView, SendaPreview/Preview.swift, scripts/preview.py, README.md and LoggerUITests.swift; create TrainingDock.swift, TrainingProfileView.swift, ProfileDetailsView.swift, TrainingLearnView.swift.
**Interfaces:** Dock selects model sections. Profile reads committed summaries and local profile, links records to Log, opens details/settings sheets. Learn keeps selected guide and search through section switches. Root supplies dock once beneath the logger's editor.
- [ ] Add native/iPhone checks for dock navigation, editable profile persistence, unit preferences, Big 3/PR source drilldown, form search/detail, incomplete edits and keyboard reachability.
- [ ] Compose minimal notebook pages and the labeled Big 3 contribution bar. Preserve existing screen identifiers and day scroll identity.
- [ ] Render normal/compact/large-text Profile and Learn plus existing logger states; inspect actual pixels. Update local preview with new screens.
- [ ] Run full local tests, native interaction probes, app host typecheck, UI syntax and diff checks. Push and run both iPhone simulator jobs; report actual results.
- [ ] Commit and ledger. Request one fresh whole-branch read-only review; fix important findings with regression tests, then finish the development branch without merging.
