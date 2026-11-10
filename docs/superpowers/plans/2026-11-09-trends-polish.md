# Trends Polish Implementation Plan

> For agentic workers: use file-owned parallel tasks and independent final review. No actual-repository commits or pushes.

**Goal:** Make recorded progress easier to scan and establish Milestones within Trends.
**Architecture:** Pure internal numerical feedback formatter, existing domain projection, native responsive rows. Data behavior stays unchanged.
**Tech Stack:** Swift6, SwiftUI/Charts, iOS17/macOS14, Swift Testing.
**Spec:** docs/superpowers/specs/2026-11-09-trends-polish-design.md

## Global constraints
Preserve ivory/clay/ink, Georgia headings, flat rows, 44pt controls, saved identities and exact canonical weights. No decorative left borders, fake targets, fitness scores, schema changes or logo changes. Preserve all current uncommitted work.

## Review focus
Mixed-sign changes must not imply strength gains. Tiny converted deltas must remain nonzero in wording. Bodyweight means added load. Paired rows must wrap/stack at compact widths and Larger Text. Milestones must retain full-history record semantics and source navigation.

## Tasks
- [x] Feedback formatter and meaningful RED/GREEN tests. Create Sources/SendaNotebook/TrainingTrendFeedback.swift and Tests/SendaNotebookTests/TrainingTrendFeedbackTests.swift. API: TrainingTrendFeedback.make(comparison:latest:previous:exercise:unit:) returns text:String, symbol:String?, positive:Bool. Neutral mixed changes show both actual deltas.
- [x] Modify TrainingTrendsView.swift: compact period totals, Exercise progress before rhythm, paired dated sets with stacked fallback, Milestones title and explicit rule. Consume formatter; retain identifiers and actions.
- [x] Preview/gallery and implementation notes: adjust full-page fixture dimensions if needed; inspect real renders at393/320 and Larger Text, including sparse/mixed/BW/kg states.
- [x] Independent review, complete suite, guarded application and final preview verification. No commits/pushes.
