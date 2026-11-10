# Picker, Trends and Profile hierarchy

The user authorized the remaining audit improvements, starting with the exercise picker. This pass implements the existing P2 backlog in `docs/design/2026-11-09-ui-ux-audit.md` using the current native SwiftUI app.

Keep search/results at the front of exercise selection. Use a compact persistent title/search header, a clearly labelled Filters control with active-filter removal, and a separate filter screen. Move ordered multi-selection, reuse and creation to More. Preserve recent/alphabetical choices, already-added states, selection order, custom metadata, reuse plans, automatic saving and failed-action cancellation.

Bring the first meaningful exercise comparison earlier in Trends. Retain the 8/12-week controls, honest dated comparisons, Milestones, empty states, frequency chart and full history. Move the aggregate period counts beside weekly context. Trends owns all-time records through an expandable section.

Keep Profile focused on personal details, units and backup/settings. Move Big 3 and personal records into a reusable Trends section without changing record semantics or retry actions. Keep Settings dismissal visible on long pages.

The chosen approach follows the accepted audit: compact hierarchy and progressive disclosure within existing screens. Leaving every action above the list would preserve the audited obstruction; removing these capabilities would lose useful workflows. No storage/model changes, format bumps or new dependencies are needed. Preserve colors, Georgia headings, 44-point actions, Larger Text and no decorative left bars. No actual repository commits or unrelated changes.

Review normal 393-point, compact 320-point and Larger Text native renders, including filtered/empty/multiselect picker states. Run existing semantic tests and update meaningful UI workflow assertions for moved controls. Mac renders do not establish iPhone keyboard or VoiceOver behavior.
