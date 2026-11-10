# Senda daily logging second pass

The user requested the next implementation pass from the UI and UX audit. This pass covers UX09 faster next-set entry, UX10 predictable exercise selection, UX11 reusable workout structure, and the related remaining UX05 hidden-exercise discoverability. Keep the approved notebook identity and all first-pass recording/retry behavior.

## Entry behavior

- New set reuses an entirely untouched blank final row instead of creating a second blank row. Preserve that row's identity and focus the appropriate Weight/Reps field.
- Keep first-time new rows blank. Show a quiet reference to the previous actual recorded set with a Use last values action. Do not automatically turn history into input or performed sets.
- Use last values fills only an entirely blank, unperformed row as editable draft input. It preserves canonical weight and bodyweight semantics and focuses that row. No performed set is created until the existing Done/navigation boundary finalizes the accepted input.
- Reference comes from the nearest preceding recorded row of this exercise in the selected day; otherwise the latest recorded row on the latest strictly earlier day. Never use an unfinished correction's raw numbers, an unperformed draft, a later row or future day as the source.

## Exercise selection

- Picker defaults to All muscle groups. Search, muscle group and equipment constraints all apply consistently. Clear filters removes group/equipment restrictions while preserving the search text.
- Show up to six recent actually recorded exercises, unique and newest first; apply the same selected filters to Recent and the browse results and avoid duplicate row IDs.
- Preserve the normal single-add path. Add an optional Select several mode with ordered selection and one explicit Add N exercises action. Already-visible day exercises are clearly marked. Additions are atomic, idempotent and create blank input only; existing sets/order are preserved.
- Empty results explain that filters may be limiting the search and provide Clear filters. Filter controls have at least44point hit areas and scalable text.
- Failed single/bulk adds retain the user's selection and offer a real retry. Successful retry or background recovery completes the intended presentation. New selection/filter intent or Cancel cancels an obsolete unpublished add, so it cannot reappear on a later recovery.

## Previous workout structure

- Offer Use a previous workout from an empty day and in the Add exercise chooser for an existing day.
- List strictly earlier days with performed sets, latest first. Show date, exercise names and the count of exercises. Copy the visible exercise order plus any retained recorded/meaningful hidden exercises.
- Reuse appends only missing exercise tabs to the destination, creates fresh blank rows only where none exist, selects the first newly shown exercise, and never copies performed values/IDs/dates or overwrites existing drafts/sets. Repeating the action is harmless.
- Preserve the existing Done/navigation boundary for any current user-entered edit. Copied structure itself adds zero performed sets. The source day stays unchanged. Failed persistence changes neither source nor destination and can be retried exactly once.

## Hidden exercises

- Rename Remove from day to Hide tab, with clear retention language.
- The All index includes visible tabs and hidden exercises with performed sets or meaningful unfinished input. Counted work always remains reachable. Selecting a hidden exercise restores its existing tab/rows rather than copying or deleting them.
- Keep original removeExercise method compatibility; do not add destructive bulk deletion in this pass.

## Shared model interfaces

- previousRecordedSet(before rowID: UUID) -> TrainingPerformanceReference?
- prefillSet(_ rowID: UUID) -> Bool
- recentExercises(limit: Int = 6) -> [Exercise]
- addExercises(_ ids: [String]) -> Bool
- indexedExercises(on day: TrainingDay) -> [Exercise]
- public struct TrainingWorkoutStructure: Identifiable, Equatable, Sendable with day: TrainingDay, exerciseIDs: [String], recordedSetCount: Int, and id equal to day.
- reusableWorkouts: [TrainingWorkoutStructure]
- reuseWorkout(from day: TrainingDay) -> Bool
- cancelPendingAction() -> Bool: cancel an unpublished failed intent while retaining the current visible input/recovery snapshot; later flush cannot apply the canceled intent. A continuing write failure may retain only that current recovery snapshot.

## Ownership and constraints

Model worker owns model/helper projections and relevant domain/model/persistence tests. Picker worker owns TrainingExercisePicker.swift, TrainingDayExerciseList.swift, new public TrainingWorkoutReusePicker(model:close:) view, and a pure tested ExerciseSelectionFilter.results(in:query:group:equipment:) helper. Root owns TrainingDayView.swift, TrainingExerciseTabs.swift, UITests, Preview and documentation. Coordinate API changes before editing other ownership.

Preserve local-only storage, old snapshots, exact hundredths of a pound, day isolation, bodyweight/zero values, pending corrections, transaction retries, existing logo/colors and readable accessibility layouts. No new dependency, cloud feature, export/restore or progress/Learn redesign in this pass. Prepare in an isolated candidate and guard the source before applying verified changes.
