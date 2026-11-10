# iPhone First Pass Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for this focused pass, with an independent final review. User authorization covers implementation of the reviewed first pass.

**Goal:** Make logging more compact and historical review predictable while preserving Senda's identity.

**Architecture:** Reuse the current recorded-history projection for all-date sessions, independent of recent chart windows. Keep history navigation state transient and use existing atomic navigation/save callbacks for explicit editing and return. Refine existing SwiftUI layout rather than replacing controls.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing; no dependencies.

**Spec:** docs/superpowers/specs/2026-11-09-iphone-first-pass.md

## Global constraints

Preserve ivory #F7F3EB, terracotta #A94E32, charcoal #302720, Georgia headings, flat lists, 44-point essential targets, automatic saving, recoverable partial input and last valid values, grouped Drop entries, and Undo. Keep a prominent dedicated Type control and paired normal compact weight/reps. No decorative left borders. No new dependencies, storage formats, commits or pushes.

## Review focus

- PR dates outside the chart window, hidden exercises and intentionally saved future records open exact recorded values.
- Incomplete corrections and partial drafts survive browsing, editing another day and return.
- Failed opening/editing/returning transactions retry once; newer navigation supersedes them.
- Returning from editing restores the original exercise, including another exercise on the same day or a week with no selected day.
- Compact and Larger Text retain readable values, controls and honest comparison dates.

## Task 1: Recorded history and navigation

Files: ExerciseProgress.swift; TrainingNotebookModel.swift; TrainingProgressView.swift; TrainingNotebookView.swift; focused domain/logger tests and affected UI navigation assertions.

- [x] Add failing regression tests for PR browsing preserving day/section, hidden records, old/future saved sessions, drafts, explicit editing/return and failed retry/cancellation.
- [x] Add `JournalSnapshot.recordedSessions(for:calendar:) -> [ExerciseProgressSession]`, reusing saved-day/recorded-value resolution and session construction. Keep recent chart behavior unchanged.
- [x] Add transient selected history day/set; route PR and reference browsing there. Add explicit session editing and a return context using existing commit/finalize transactions.
- [x] Update History to show all-date Recorded days independently of chart emptiness, exact selected set and an explicit editing action; add persistent workout return navigation.
- [x] Run focused tests red then green and update previously intentional PR-to-Log expectations.

## Task 2: Workout and Trends hierarchy

Files: TrainingDayView.swift; TrainingPlanSummary.swift; TrainingSetTypePicker.swift; TrainingTrendsView.swift; Preview.swift.

- [x] Combine plan count/target and collapsed references, retain full controls and numeric layout. Clarify previous-workout reference wording.
- [x] Reduce Trends introduction and use compact source-set rows when readable, with Larger Text fallback.
- [x] Add focused native preview states for old history, selected PR and historical edit return. Build and visually inspect matched compact/phone/Larger Text states.
- [x] Verify the 44-point improvement target without treating full-height export whitespace as a defect.

## Task 3: Review and integration

- [x] Run the full semantic suite, compile native preview, and run iPhone checks if the installed Xcode/runtime supports them.
- [x] Have an independent reviewer inspect the exact delta, navigation and test evidence; resolve substantive findings.
- [x] Record validation and preview paths. Compare target files against the captured baseline before applying, preserving concurrent edits.
- [x] Apply only this pass's changed files to the app repository and verify the applied content. Do not commit or push.
