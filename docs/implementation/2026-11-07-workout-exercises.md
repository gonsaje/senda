# Workout exercise tabs

The user confirmed that each tab is an individual exercise in the current workout. They want to add exercises from a preset library or create a custom exercise, without a three-tab limit. Keep the current set logger, dual units/dial, explicit recording and Done corrections, PR/Common references, and automatic recovery. Preserve approved planning/architecture documents.

## Product and domain decisions

- Tabs represent the current workout's ordered exercise selection, rather than a globally sorted recent-lift index. Preserve the existing Bench/DL/Squat starting selection for compatibility, then allow any number of additional distinct exercises. Recording must not reorder tabs.
- A pinned + opens a searchable exercise picker. It offers a larger preset library and locally saved custom exercises. Selecting an existing workout exercise switches to it; adding another appends/selects it. A clear Create exercise action accepts a name and adds it to both the library and workout.
- A tab context menu can remove it from the workout while keeping its history and per-exercise session. Keep at least one exercise in the workout. Re-adding a removed exercise restores that session, rather than silently replacing unfinished sets.
- Custom names are trimmed and whitespace-normalized, 1–80 characters, with deterministic case/diacritic-insensitive duplicate detection against names and short names. Stable custom IDs survive reopening. No catalog deletion or rename in this change.
- New presets/custom exercises with no history start at zero load, four sets and ten reps, as editable suggestions. Existing three presets keep their prior defaults. Suggestions never enter performed history until Record.
- Keep the existing numeric-edit boundary when switching: valid pending input is staged before switching; invalid input blocks switching/add/remove with a clear error and remains intact. Pending recorded corrections remain pending in their exercise session.
- This scope is exercise tabs, not named workout templates, a calendar, workout completion, scheduling, cloud or backend.

## Architecture and storage

- Extend Exercise to Codable and provide a preset library, custom-name creation/validation and catalog lookup in SendaDomain. Do not move persistence into domain models.
- Add optional workoutExerciseIDs to EntryWorkspace. Missing legacy metadata means the original three tabs. Validate a nonempty, unique, known list containing the selected exercise. Retained sessions may belong to known exercises outside the visible workout, so removed tabs keep their work.
- Add optional customExercises to JournalSnapshot for backward decoding. Snapshot validation combines presets with the saved custom library before validating workspace references. Do not reject arbitrary legacy journal exercise IDs just because they are outside the visible library; preserve their performed records.
- File format 3 writes history, recovery, custom library and workout order atomically in one envelope. Load versions 1/2 without rewriting; version 3 requires its custom-library field. Unknown/corrupt formats remain untouched. Keep journal-v1.json as the filename. Journal-only repository convenience saves must preserve both workspace and custom library.
- LoggerModel publishes added/removed tabs and custom exercises only after the candidate snapshot is saved. All record/correction/undo/recovery paths retain the custom library. Preserve existing failed-write semantics and per-lift stable set/action IDs.

## Implementation plan

1. Add failing domain, storage and logger tests for catalog creation/duplicates, more than three tabs, stable ordering, per-exercise recovery, failed additions/removals, custom recording/correction/undo/PR, legacy format migration and metadata preservation.
2. Implement the domain metadata and format-3 repository. Update the old migration assertion to format 3 and retain actual version-2 fixture coverage.
3. Extend LoggerModel with availableExercises, workoutExercises, addExercise, createAndAddExercise and removeExercise. Centralize snapshot creation so every writer retains custom metadata. Preserve and restore workout order.
4. Add a focused WorkoutExerciseTabs view, searchable ExercisePickerView and small custom-name creation view. Keep the main notebook minimal; preserve the existing picker-independent per-set editor.
5. Run the complete unit suite and host app typecheck; inspect regular/compact native renders. Add iPhone interaction tests that add a fourth preset and custom exercise, log/reopen it, verify history isolation and restore a removed tab. Request independent review and run both phone checks on a development branch before handoff.
