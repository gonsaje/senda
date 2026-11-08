# Previous and next day

**Goal:** Move one calendar day backward or forward directly from the day view.

**Design:** Place quiet chevrons around the existing date, with 44-point tap targets and Previous day / Next day accessibility labels. Keep Week available. At large text sizes, let the date controls occupy their own row instead of squeezing the date. Keep the notebook palette and type. A swipe-only gesture would be less discoverable and compete with the exercise tabs, so use visible buttons.

**Architecture:** Add `TrainingNotebookModel.changeDay(_ direction: Int) -> Bool`, using calendar-day arithmetic and the existing `openDay` transaction. Completed edits save before leaving; incomplete rows remain recoverable without entering progress. A failed write keeps the current day and inputs. Each destination retains its own exercises, selection, units and sets; an empty day starts empty. Returning to Week shows the destination's week. Keep the scrolling view alive while resetting its transient scroll/sheet state when the date changes. Reference links still reveal their selected set.

**Constraints:** Native SwiftUI, local storage only; no new persistence format or dependencies. Preserve approved planning/architecture files and user-created files. Work on `codex/day-navigation` in the existing preview checkout.

## Plan

One task, implemented directly with one independent review at the end.

- [x] Add failing behavioral tests for adjacent-day navigation across Sunday/Monday, completed and partial input, reopening, and failure/retry atomicity.
- [x] Implement the model command and accessible header arrows, preserving empty-day behavior and resetting transient view state.
- [x] Extend existing iPhone flows for saved-row round trips, partial input while changing days, and large-text navigation. Refresh normal and compact native previews and README.
- [ ] Run the full suite, inspect layouts, review the branch once, push it, and run both iPhone checks.

Review focus: off-by-one dates at week/month boundaries; saving into the source day; incomplete rows staying outside progress; failed writes retaining focus and selection; narrow screens and large text keeping date controls reachable. Domain and storage schemas remain unchanged.

Native preview correction: replacing the entire day view by date caused macOS to create a 32-point scroll-edge header after navigation. Reusing the scroll container removes the bar; an explicit day-change handler resets the tab, sheet and ordinary top scroll position. A native comparison reproduced the bar before the change and passed after it, including a long scrolled workout. The iPhone navigation flow also checks that the Week control stays at its original vertical position.
