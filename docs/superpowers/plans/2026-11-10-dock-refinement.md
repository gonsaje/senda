# Bottom Bar Refinement Implementation Plan

**Goal:** Keep all four bottom-bar labels readable and reachable at the largest text size.

**Architecture:** Refine only TrainingDock presentation and add iOS Large Content Viewer. Keep model actions and all page content unchanged. Extend the existing largest-text navigation test and add a focused preview mode.

**Tech stack:** SwiftUI, native XCTest, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-10-dock-refinement.md`.

**Scope:** TrainingDock.swift, LoggerUITests.swift, Preview.swift, README.md, this spec and plan (six files). Preserve colors, four section identities/order, 54-point button minimum, fully scaling page/key values and model/save behavior.

- [x] Read guidance and independently audit the source/native screenshots; verify Apple's tab-bar Large Content Viewer guidance.
- [x] Add full-label, nonoverlap, one-row alignment, minimum-target, selected-state and height checks before product changes. Native compact baseline fails: 173-point dock exceeds 120-point bound.
- [x] Cap only label Dynamic Type at xxxLarge, keep full labels on one line, align icons and add a small selected checkmark. Add iOS large previews outside the size constraint.
- [x] Inspect fresh normal/compact/Largest Text renders and native screenshots, including the held large preview.
- [x] Pass focused native navigation/recovery checks and full semantic suite, including TrainingSectionTests' unfinished input and failed-save switch cases.
- [x] Obtain independent final review; apply six baseline-checked files and verify hashes/whitespace. No commit or push.

Use layout assertions for this reported visual regression and existing model coverage for navigation/save safety. Review artifacts live under output/dock-refinement in the review workspace.

## Verification

The full semantic suite passes 455 tests in 57 suites, including TrainingSectionTests for automatic saves, unfinished 31. input, failed section switching and retry. Native iPhone 13 mini Largest Text checks pass for all four complete labels, nonoverlapping/equal-row button frames, minimum 44-point targets, containment within a compact bar, selected states, Profile units, Learn search/result and return to the week. Native iPhone 16 standard-size recovery passes after switching sections, editing a name and units, relaunching and restoring unfinished workout input. Its standard week capture retains all seven days above the bottom bar.

A native screenshot during the three-second Profile hold verifies the full system Large Content Viewer label and symbol. The initial test assumed the hold navigated; a normal tap now verifies navigation separately. The older Learn step typed Bench without submitting; the updated step uses the existing Search action and checks keyboard dismissal before opening the result. Both adjustments affect only the test's interaction sequence; no page/model or shared-helper workaround was introduced. The final compact flow passes.

Fresh renders cover all four selected states at 393/320-point widths and Largest Text fixtures. Native before/after captures show the wrapping resolved; page text remains fully scaled. Independent source and visual review closed without production-code findings, and the test corrections resolve the review finding.

Applied six focused files after destination baseline checks and verified source hashes and whitespace. Page content/layout, models, persistence, palette and branding remain unchanged. Review captures, original source backups, patch and application manifest are under output/dock-refinement in the review workspace. No commit or push.
