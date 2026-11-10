# Trends overview and progress feedback

The user requested a Trends section and useful visual feedback on progress after per-exercise history was added. The logo/type study remains a proposal; this pass does not choose or replace the approved branding.

## Experience
Give Trends a main navigation tab alongside Log, Learn and Profile. Use the same 8/12-calendar-week range as exercise history, including the current partial Monday-based week through today. Show exact date bounds and flat, readable period totals: unique recorded training days, performed sets and exercises trained.

This week shows recorded days and sets so far, compared only with the same elapsed weekdays last week. Weekly frequency bars include zero-activity weeks. Missing activity is not a missed goal and no target is invented.

Performance rows compare the latest recorded day's top set with the immediately preceding recorded day's top set within the selected window. Equal load permits a rep change; equal reps permits a load change; identical values are matched. If both differ, show the two actual sets without assigning a gain/loss score. One day is insufficient for a comparison. Always show rep/load context and dates. No cherry-picking a more favorable old set.

Recent recorded bests compare daily top sets with all prior recorded days, using the app's load-then-reps record definition. A first-ever day is a baseline, not an improvement; exact ties are not new records. Show at most the latest event per exercise, with the UI initially showing three. These observations do not claim strength or fitness changes.

Each exercise or record row opens the existing exact-set history. Done returns to Trends; Return to workout keeps the original selected workout/day/exercise. Profile's existing Progress entry is labeled Exercise history to distinguish it from the overview.

## Data and presentation
Only journal performed values count. Persisted training-day links take precedence over timestamps. Include retained hidden/custom/legacy history; exclude future dates and draft/correction text. Corrections, deletion, Undo and restore recompute from the same source. Canonical weights stay exact; unit conversion is display-only. No analytics persistence or schema change.

Keep the ivory/clay/ink palette and Georgia hierarchy. No decorative left borders, fake goal rings, repeated dashboard cards or motivational filler. Use clear numbers, meaningful direction symbols, ordinary separators and native Charts. Negative differences remain neutral recorded observations; text and symbols carry meaning beyond color. Targets stay44pt and compact/Larger Text layouts stack rather than truncate values.

## Approach
Reuse the pure progress projection and shared weekly chart/range control. A whole-notebook projection supplies unique activity counts, fair comparisons and strict record events. Add no new dependencies. Develop in an isolated snapshot, preserve current uncommitted work and apply reviewed files with hash guards. Native render review, meaningful test-first domain/model cases and the complete existing suite precede application. iPhone VoiceOver/real Dynamic Type remain device validation when Xcode is unavailable.
