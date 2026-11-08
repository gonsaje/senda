# Day exercise list

Next focused improvement: an index of every exercise added to the selected day. The optional direction question offered this and exercise history; proceed with the recommended index after allowing time for a reply. The user can steer the direction while development continues.

Use a compact All N action beside the selected exercise title whenever the day has multiple exercises. Preserve horizontal tabs for quick switching. The index shows full names, performed-set counts (No sets yet for incomplete/unperformed rows), a clear current selection, and Add exercise. Selecting an exercise returns to its existing rows and brings its tab into view. The index uses the existing notebook palette and typography.

A separate row below the tabs would use extra vertical space; a title-side action provides access without enlarging the compact day header. Reuse the existing selection and persistence commands. This pass adds browsing, selection and the path to Add exercise; it does not include an exercise-order editor or a history browser.

Finish current editing successfully before opening the index. Never count incomplete rows or mix counts from other exercises/dates. Failed selection writes keep the index open with its current selection and error. Use one sheet route for the list and picker. Closing the sheet returns to the same day.

Plan:
- [x] Add and test loggedSetCount(for:on:) as a read-only application projection.
- [x] Build TrainingDayExerciseList and the title-side All N entry point; reuse selectExercise and the existing picker.
- [x] Add native eight-exercise renders and browser review; extend an iPhone flow to verify counts, selection, returning to original rows, Add exercise and reopening.
- [ ] Run the full suite, inspect normal/compact layouts, review the complete changes and run both iPhone checks before handoff.

Review focus: day/exercise isolation; incomplete rows versus actual counts; failed writes; selected exercise and input recovery across sheet transitions; full names and controls on narrow screens/large text. Domain and persistence formats remain unchanged. Approved planning/architecture documents stay intact.
