# Picker, Trends and Profile Implementation Plan

> **For agentic workers:** Use focused parallel implementation with independent review before integration.

**Goal:** Finish the accepted audit's picker, Trends and Profile hierarchy work.

**Architecture:** Keep presentation state local to the existing SwiftUI views. Reuse current model transactions and extract records into a shared view owned by Trends.

**Tech Stack:** SwiftUI, Swift Testing, native macOS preview renderer.

**Spec:** `docs/superpowers/specs/2026-11-09-navigation-ux-pass.md`

## Global constraints

Preserve existing saved data and failed-action cancellation. No new dependencies or persistence formats. Keep ivory, terracotta, charcoal and Georgia. No decorative left bars. Essential targets at least 44 points. No repository commits or pushes.

## Review focus

- Failed add followed by new filter/search/selection intent must not later navigate using stale retry.
- Multi-selection order survives filtering; already-added choices remain distinguishable.
- Empty/filter/custom/reuse states retain a reachable next action and dismissal.
- Larger Text may wrap/stack; labels and numbers must not shrink to fit.
- All-time records remain available outside the selected time window, with existing edit/retry actions.

## Tasks

- [x] Picker: replace preamble with persistent compact navigation/search, secondary More actions and a separate filters panel. Preserve transaction helpers. Verify rendered recent, filtered, empty, ordered selection and Larger Text states. Update existing UI workflows for filter navigation and menu actions.
- [x] Trends: reduce preamble/heading scale, lead with comparisons, relocate period counts and add expandable all-time records. Preserve comparison facts, chart details, range and empty states.
- [x] Profile: move records to TrainingRecordsSection; show ordinary details/units/backup destinations and local storage context. Keep Settings dismissal persistent. Update UI flows to find records in Trends.
- [x] Review the integrated diff, run the full test wrapper and native renders. Correct concrete findings, then guarded-copy only reviewed files into the actual repository and verify untouched baseline hashes. Refresh the live gallery and save evidence.
