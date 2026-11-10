# Workout plans, set type and effort

The user approved planned sets/rep ranges, warm-up marking and optional reps left to support useful next-workout guidance. Implement the inputs plus conservative, explainable guidance in the workout. Keep the existing Senda visual system and all recorded/draft/retry semantics.

## Plan and annotations

ExercisePlan stores workingSets1...30, minimumReps1...999, maximumReps1...999 (min<=max). Store optional exercisePlans per DayWorkout, keyed only to retained exercise rows. Plans belong to that workout. Adding an exercise for the first time on a new day can inherit the plan from its nearest earlier workout containing that exercise (including an absent/removed plan); prior workouts never change. Reusing a previous workout copies source plans only for newly added exercise rows; destination data remains intact. Saving/removing a plan edits only the selected workout. Plans do not create recorded sets or fill numeric rows.

TrainingRow gains optional kind (working/warmup) and repsInReserve (Int0...5, where5 means5+). Missing legacy fields stay nil/unknown, including migrated performed/draft rows. Model-created new rows explicitly start working with no effort. Repeat copies set kind but clears effort; prefill clears effort without importing past effort. Delete/Undo preserves the full annotation. Marking a set or editing a plan is metadata-only and must not finalize or accept pending numeric corrections. Invalid metadata, including deleted undo rows, is rejected.

Existing all-recorded-set history, totals and PR semantics remain intact. Guidance and planned-set completion use only explicit working sets, excluding warmups and unknown classification. History details show the annotations, making observed records auditable.

## Guidance

Pure projection reads the context workout’s plan and journal-performed values resolved through saved civil-day links, never draft numeric text. Include observations on/before min(context day,today), so a completed context workout can inform its next exposure; future records do not count. No plan/history => explain what is missing. The latest recorded day with working/unknown sets is authoritative; never skip an unfavorable, incomplete or differently planned latest session to find favorable data. Explicit warmup-only days do not establish a working session. Unknown set types block inference until classified.

Comparable complete sessions require identical saved plan values, exactly the planned working-set count, no unknown recorded types, and a common canonical load within each session. Different plans, extra sets or mixed loads prompt review. Incomplete latest working sessions prompt completion. Below-range reps prompt reviewing load/rest/target. Missing effort means unknown, not zero, and only supports repeating a load/range. Any reported reserve below2 prevents a readiness suggestion. With all recorded reserves>=2 and reps still below the top of the range, suggest building reps within the plan. Two consecutive comparable sessions at the same canonical load, every working set at/above the top rep target and reserve>=2, can suggest reviewing a small load increase; never choose an amount or change a load automatically. These are transparent conservative app rules, not a universal physiological threshold or strength diagnosis.

## Native flow

A flat Plan row below the exercise header shows working-set target, rep range and exact recorded working-set completion. Plan editor uses native controls, Cancel/Save/Remove, clear bounds and inline retry. Reuse existing pending-sheet save workflow; preserve unfinished input. Set ellipsis retains its existing delete-reveal behavior for backward interaction compatibility; use its revealed action area or a separate compact native Set details action to edit kind/effort, preserving swipe deletion and accessibility actions. The implementer may use a native Menu if all existing interaction tests and deletion actions are preserved. Metadata editors explicitly abandon older pending-save intents on entry without finalizing input, and expose Retry only for their own failed Save/Remove in a matching context. Keep recorded/unfinished/pending-correction state labels visible. Show concise Next workout feedback in the day view; no new coaching dashboard or changes to Trends calculations. Read-only exercise session detail shows type and effort.

## Compatibility and verification

Write local journal format5 and full-backup version2 so older app versions reject new data rather than silently dropping annotations/plans. Read local formats1...5 and full-backup versions1...2; old fields absent remain unknown. Full JSON preserves plans, row metadata and undo. CSV appends Set Type, Reps Left, Planned Working Sets, Minimum Reps, Maximum Reps columns; unknown metadata stays empty. Failed saves/restore retain atomic recovery behavior.

Test-first domain projection/validation and model workflows; serialization old/new roundtrips, invalid metadata/undo, CSV and restore protection. Run all existing tests, native normal/320/Larger Text/failure/sparse states, independent review and guarded application. Preserve uncommitted work; no actual-repository commit or push. iPhone/VoiceOver runtime validation requires full Xcode.
