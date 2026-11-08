# Unit placement and set-row actions

Move the display unit into a compact lb/kg menu beside the exercise heading. Keep it out of the numeric columns, with the existing exact conversion and day-wide unit behavior. Preserve unit action identifiers, local recovery, approved architecture documents and existing user files.

Replace the minus button with a 44-point vertical-dots action at the right edge of each row. Tapping it, or a short left swipe, reveals a red X delete action. A full swipe deletes on release after actual travel reaches 60% of the row width (at least 120 points); predicted velocity never deletes. Vertical gestures stay vertical for their full duration, cancellation never deletes, and only one row stays open. Right swiping closes a revealed action. Deletion calls the existing atomic deleteSet command; failed writes retain the row with a retryable action. Existing targeted Undo restores the row in its original order.

Plan, one implementation task:
- [x] Add failing tests for direction locking, reveal/close, full-distance deletion, cancellation and invalid geometry in a UI interaction test target.
- [x] Extract the swipe row component; reuse existing field buttons, delete and undo commands. Move units to the heading menu and simplify table labels.
- [ ] Update the iPhone interaction flow for the unit menu, partial reveal/red X, full swipe and Undo. Inspect native normal, compact and revealed-row states, run the whole suite, review once, then push and run iPhone checks.

Review focus: unintended deletion during vertical scrolling or interrupted gestures; stable row identities and order through Undo; failed writes and pending edits; tapping numbers without opening row actions; unit-menu reachability at narrow widths and large text. Keep the stable day scroll container and dial editor intact.
