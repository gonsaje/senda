# Trends overview

Trends is a main tab between Log and Learn. It uses the notebook’s existing recorded sets and the same shared 8/12-calendar-week selection as Exercise history. The current partial week ends today; all weeks start Monday. No analytics data or schema is stored.

## What the numbers mean

- Period totals count unique saved training days across exercises, performed sets and active exercises. Drafts, unfinished correction text and future dates do not count. Saved civil-day links take precedence over timestamps; unknown/hidden/custom retained exercises remain included.
- This week so far compares only the same elapsed weekdays last week. The chart includes inactive weeks and exposes exact weekly day/set counts in a disclosure. No target or missed-goal state is inferred.
- Each Exercise progress row compares the latest two recorded days in the window. Equal load shows a rep difference; equal reps shows a canonical load difference; equal values are matched. When both change, both dated sets are shown without assigning a gain/loss score. One recorded day cannot establish a trend.
- Milestones use the daily top set ranked by load then reps, against all prior recorded days, including history outside the window. A first observation establishes a baseline and exact ties are excluded. Only the latest qualifying event per exercise is listed; initially three appear with Show all for the rest. These are observed records, not estimated strength or fitness changes.
- Default lb/kg is display-only. Tiny nonzero converted changes are labeled less than 0.01 kg rather than rounded to a false zero. Bodyweight rows distinguish bodyweight and added load.

## Interaction and presentation

The four labeled tabs retain selected traits and 44-point targets. Shared range controls use a checkmark and text emphasis. Larger Text stacks the header and totals; rows wrap and separate dates from values. The view uses the established ivory, ink, terracotta and olive colors, Georgia headings, flat rows and ordinary rules. It adds no decorative left borders, goal rings, empty graphs or motivational copy.

Exercise rows and History open the existing read-only sheet. Done returns to Trends. Return to workout selects Log with its prior day and exercise. Profile’s former Progress entry is labeled Exercise history. Entering Trends finishes a valid set or retains unfinished input, using the existing atomic save and retry behavior.

## Verification

New domain tests cover overall-day deduplication, empty/8/12-week windows, inactive and partial weeks, calendar boundaries/DST, saved-day precedence, adjacent-day comparisons, bodyweight/mixed loads, exact canonical differences, custom/hidden exercises, strict full-history records, first/tied observations and corrections/deletion/Undo. New model tests cover navigation, incomplete input, failed-save retries, no-write browsing, return destinations, pending corrections and restore recomputation.

Native preview fixtures cover regular/compact screens, Larger Text, empty and one-day history, bodyweight/added-weight and increasing/decreasing/matched/both-changed comparisons. These are real SwiftUI renders hosted on macOS at phone dimensions. iPhone interaction tests are added to the existing UI suite, but require full Xcode and an iOS runtime to execute. Final command results are recorded in the delivery artifacts; no iPhone or VoiceOver execution is claimed on this Command Line Tools machine.

## UI clarity pass

The user chose Trends for the main tab and Milestones for recorded achievements, connecting Senda’s path meaning to progress over time. The compact period totals lead into Exercise progress, then Milestones, then the fair current-week comparison and training rhythm chart. Removing the duplicate large period heading and tightening section spacing brings comparisons higher without reducing touch targets.

Mixed changes state both canonical differences in neutral wording, such as “10 lb more · 2 fewer reps.” Like-for-like comparisons use more/less/fewer wording, retain the source sets and keep nonzero converted deltas honest. The internal feedback formatter contains no journal commands or fitness-score calculation.

Latest and previous dated top sets pair only when there is room for both intrinsic text widths, otherwise stack; Larger Text explicitly stacks. Milestones explain the load-first, reps-at-the-same-load criterion. No goal badges, decorative paths or stock journey copy were added. Existing identifiers, history actions, recorded/draft distinctions and full-history record calculations remain unchanged.
