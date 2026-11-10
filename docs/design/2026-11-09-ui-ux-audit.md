# Senda UI/UX audit — November 9, 2026

The main problem is task priority. The workout screen gives navigation, repeated exercise names, references and optional controls more space than the sets. On narrow screens, each set becomes a long form. The duplicate Regular/Working distinction and disconnected Drop rows add conceptual work as well as taps.

This review uses actual native SwiftUI renders, their source structure and the intended logging/history flows. It is an expert review, not a participant usability study. Native Mac previews are not iPhone simulator captures. Oversized full-page exports were used to inspect content; their blank trailing areas are not evidence of layout defects. Phone-size captures were checked separately.

## Priority findings

| Priority | Finding | Evidence and user impact | Action |
| --- | --- | --- | --- |
| P1 | The workout header delays set entry. | Date navigation, tabs, repeated Bench title, plan and references occupy roughly 385 logical points before the first set in the previous compact export. The same selected exercise appears twice. | Combine date controls, use one exercise selector, and collapse references. |
| P1 | Compact set rows are too tall. | The previous compact layout stacks Type, Weight and Reps separately; a row occupies about 300 points. Four sets require roughly 1,200 points before New set. | Keep weight and reps alongside each other on normal narrow screens. Use full stacking for Larger Text. |
| P1 | Optional effort dominates every row. | An empty Reps left control adds a full 44-point line even when the user has no effort value to add. Ordinary rows are about 110 points high. | Put effort editing in row actions; show a quiet summary only when a value exists. |
| P1 | Regular and Working set are duplicates. | Both count toward the same target and use the same guidance. Their definitions do not explain a meaningful difference. | Offer Working set as the default. Preserve Regular only as a compatibility alias for saved data. |
| P1 | Drop is a label, not a usable sequence. | Standalone rows expose no relationship between a starting set and its drops. The user confirmed one grouped entry with weight/reps stages. | Group Start, Drop 1, Drop 2 and later stages explicitly. Keep all values editable and saved, with one displayed set total. |
| P1 | Navigation scrolls away on long reference pages. | Progress Back/Done and Learn back controls were children of the same ScrollView as the long content. | Keep those controls outside the scrolling content. |
| P2 | Exercise picker secondary controls precede exercises. | Title, search, filters, bulk selection and reuse consume much of the initial viewport before exercise choices. | Keep search and results first; move secondary actions into a small toolbar/menu. |
| P2 | Trends/Progress have too much preamble. | Compact Trends reaches its first comparison late; compact Progress spends nearly the first viewport on headings, range explanation and summaries before the chart. | Show the latest result/comparison sooner. Use a smaller shared title hierarchy and compact summaries. |
| P2 | Profile mixes unrelated jobs. | Identity, preferences, backup guidance, history destinations, Big 3 and records compete. Progress/history also live in Trends. | Give Trends ownership of progress and history; keep Profile focused on personal details and settings. |
| P2 | Learn delays the useful form cues. | Large form and anatomy illustrations precede Set up, Move and Keep in mind. | Put short technique cues next to the form positions; move detailed anatomy after the cues or into a disclosure. |
| P2 | Headings and navigation destinations look alike. | Some destinations use large Georgia headings while comparable destinations use ordinary rows. | Use consistent page titles, section titles, result values and destination rows. |

## First repair pass

The implementation prioritizes the six P1 issues above. It retains the existing colors and Georgia identity, the separate Type control, visible units, explicit selected states, 44-point actions and automatic saving. It also reduces the Progress heading preamble, keeps history navigation persistent, places form cues before detailed anatomy in Learn, and pins save-error recovery above the bottom controls.

Grouped Drop data needs explicit membership, not inferred adjacency. Each stage keeps its own saved values and identity; the displayed entry and set totals count the group once. Historical standalone Drop rows remain standalone. Group delete/repeat/Undo and backups must preserve every stage. Working-set guidance continues to request manual review for Drop workouts.

The remaining P2 items are a prioritized backlog, not claims that the entire app has been redesigned. A later pass should work through the exercise picker, Trends, Profile and the remaining shared hierarchy in that order, with before/after phone-size review and a small set of shared layout components.

## Status after the first pass

Working is the standard choice; Drop logging is now a grouped sequence. The workout header and rows have been rebuilt, effort is contextual, and long reference pages keep their return controls visible. Learn now places coaching cues before anatomy. The earlier compact export used roughly 300 points per ordinary set; the revised paired-value row uses roughly 125 points in the inspected normal-text render. Number sizes were retained. These are approximate measurements of native Mac renders, not device benchmarks.

Still queued: exercise-picker secondary controls, Trends preamble, Profile's mixed responsibilities, and a shared hierarchy across the remaining destinations. Progress's heading preamble has been reduced, but its broader chart/summary layout remains on that list.

## Acceptance criteria

- A normal working row does not reserve a line for empty effort metadata.
- Weight and reps remain readable together at 320-point width; Larger Text can stack them without truncation.
- The selected exercise has one primary title/control, with clear access to Add, all exercises, history and units.
- Working is the only standard set choice; old Regular values display as Working and still load without rewriting.
- A Drop entry shows its starting stage and every subsequent drop together. Adding a stage does not create another displayed set.
- Valid stage updates save immediately; incomplete text and actual storage failures remain recoverable.
- Whole-entry repeat, delete and Undo preserve canonical values, dates and identities correctly.
- Back/Done remain visible while browsing long history and Learn content.

## Evidence and method

Baseline renders are preserved under `/Users/jaesong/Documents/ChatGPT/senda/output/ux-review/before/`. The first comparisons use the previous set table, compact table, active editor, Trends, Profile, Learn guide and exercise history. New renders belong under `output/ux-review/after/` after integration.

The review follows Apple's guidance to order information by task importance, align related data, disclose secondary choices and adapt to available space. These are used as review criteria; they are not a reason to introduce a different visual theme. [Apple Human Interface Guidelines: Layout](https://developer.apple.com/design/human-interface-guidelines/layout).

No on-device keyboard, VoiceOver or real lifting-session testing has been performed here. Those checks remain necessary before release, particularly for stage entry, contextual menus and recovery from an interrupted save.


## Second repair pass: picker, Trends and Profile

The picker now leads with a compact persistent heading and search. More contains multi-selection, previous-workout reuse and creation. Filters have their own panel; applied filters remain visible and individually removable. Ordered selections survive search/filter changes, and existing pending-action cancellation/retry helpers remain in use. Empty results offer clearing filters or creating an exercise. Picker, creation and reuse retain reachable return controls.

Trends presents exercise comparisons before period totals. Milestones remains the achievements section, and an expandable All-time records section owns Big 3 and personal records. Those records remain available when the selected time window contains no sets. Profile now presents details, units and a direct Backup & restore destination. Settings keeps Done visible. Page and section headings across these screens, Progress and the Learn catalog use a consistent scale; summaries use flat aligned values.

In the inspected 320-point Mac render, the picker shows six exercise choices in the initial viewport versus two before. This is a layout observation, not an on-device usability benchmark. Larger Text branches, filtered/empty/multi-selection states, zero/incomplete records and bodyweight records are included in the native review gallery. Keyboard, VoiceOver and actual iPhone interaction still need device verification. No model or storage-format changes are part of this pass.
