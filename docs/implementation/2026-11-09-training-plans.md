# Workout plans, set type and reps left

Per-workout exercise targets contain working-set count 1...30 and a minimum/maximum rep range 1...999. Plan changes never create performed sets or fill numeric rows. A newly added exercise inherits the plan of its nearest earlier workout, including an explicit absence; choosing a previous workout reuses its plans only for newly added exercise rows. Existing and historical data remain intact. Hiding an exercise retains its plan.

Optional TrainingRow kind and repsInReserve store working/warmup and 0...5 (5 means 5+). Legacy decoding/migration leaves missing fields unknown. New model rows explicitly begin working with unknown effort. Repeat copies kind but clears effort; prefilling clears effort. Full deleted-row Undo restores annotations. Existing recorded history/PR/Trends totals continue to include all performed sets. Plan progress and guidance use explicit working sets only.

## Guidance rules

The pure projection resolves values from the journal using saved civil-day links, including the completed context workout and excluding later/future records. It cannot consume pending numeric correction text or inferred effort. Warmup-only days do not establish working sessions; unknown classification blocks inference. The latest relevant session and its immediate predecessor are authoritative, so a favorable older workout cannot replace an incomplete or unmatched one.

Comparable sessions share the saved plan, have exactly the planned working-set count and one common canonical load. Missing/changed plan, extra/incomplete sets, mixed loads or below-range reps return review messages. Unknown effort never becomes zero. Reserve below 2 holds load review; sufficient reported reserve with room in the range supports building reps. Two consecutive comparable sessions at the same load, all sets at/above the top target and all recorded reserves>=2, support reviewing a small increase. This is an explicit conservative product rule, not a universal physiological threshold or a measured strength/muscle-gain claim. No load amount is selected or changed automatically.

## Transactions and UI

Plan/type/effort edits are metadata-only and preserve numeric focus, unfinished text, corrections and all row/action/performed identities. Failed committed writes do not publish metadata; retry saves the exact candidate. Editor entry supersedes inherited failed finalize/navigation actions without accepting numeric input. Only the editor’s own pending save offers Retry, and Cancel/dismiss/context changes abandon its action. This closes a review-discovered ownership bug covered by three behavioral regressions.

The exercise day has a flat Plan row, working-set completion, a separate Set details action preserving ellipsis/swipe deletion, and Next workout text when not numerically editing. Native editors have 44pt controls and selected checks; Larger Text stacks. Exercise-history set detail shows type and effort. No coaching dashboard, decorative paths/left borders or fabricated records are introduced.

## Persistence

Local journal writer is format 5; reader accepts 1...5. Full backup writer is version 2; reader accepts 1...2. Older readers reject new versions rather than silently dropping new data. The protected restore-pair recovery format remains 1. Existing files are not rewritten just by loading. Plans/annotations/undo live in existing workspace structures and participate in atomic save/restore.

CSV retains its original ten columns and appends Set Type, Reps Left, Planned Working Sets, Minimum Reps, Maximum Reps. Unknown values remain blank; reserve 5 exports as 5+. Canonical lb/kg values, source IDs, timestamps and saved day membership remain exact. Drafts and correction text never enter performed CSV rows.

## Verification

Meaningful test-first cases cover domain validation/projection, model lifecycle and failed-action ownership, local/backup roundtrips and versions, legacy unknown fields, deleted Undo, exact CSV and failed writes. Native fixtures show plan/default editors, working-set details, compact/Larger Text, review-load, build-reps, unknown effort/type, incomplete sets and bodyweight. iPhone interaction-test source covers non-recording plans and warmup/effort/repeat semantics; actual execution requires full Xcode/iOS runtime. Mac-hosted renders do not certify real iOS scaling or VoiceOver. Final command results and applied hashes are kept with delivery artifacts.
