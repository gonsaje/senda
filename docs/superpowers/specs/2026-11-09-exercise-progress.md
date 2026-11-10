# Per-exercise history and observed trends

The user approved the next audit item UX12: per-exercise history and trends over 8–12 weeks, following completed backup and Profile cleanup.

## Experience
Progress is available in Profile and directly beside an active exercise. It opens over the current notebook, preserving the selected workout/day/exercise. A searchable list includes exercises with recorded history; a direct active-exercise link can show its empty state. Default12 calendar weeks, optional 8; include the current partial Monday-based week through today and print exact date bounds.

Each detail shows dated daily top sets, latest/period-best observations, recorded training-day/set counts, and weekly training frequency including zero weeks. A weighted exercise plots its heaviest recorded set each day, with reps alongside the load; it makes no estimated1RM/strength-gain claim. A bodyweight-only period plots its highest reps. Mixed bodyweight/added-weight sessions plot added weight, including actual zero observations.

Newest-first session history opens the exact recorded sets in a read-only view inside Progress. Back returns to the trend; Done dismisses Progress; Return to workout returns to Log with the original day/exercise intact. History browsing itself never rewrites workout selection or creates a performed set. Opening/returning uses the app's existing valid-set finalization and failed-action retry boundary.

## Data rules
Derive all history from performed journal sets. Persisted training-day keys and row order take precedence over timestamps; group all batches on the same training day into one session. Hidden/custom/legacy exercises remain included. Draft values and unfinished correction text never replace performed values. Filter future/out-of-window dates. Corrections, deletion, Undo, units and restore recompute observations from the same source.

Use immutable pure domain projections, native Swift Charts, and text/session alternatives with semantic headings and 44-point controls. No new dependencies or storage schema. Keep Senda ivory/clay/ink and Georgia. Charts use points/straight segments, not forecasts or fake zero-strength values. Sparse/empty periods must remain useful.

## Chosen implementation
A pure snapshot query plus a modal progress browser keeps current-workout context intact without adding a new primary tab or persisting analytics. Editable historical navigation is outside this pass; original recorded sets are inspectable in place. This is the smallest complete implementation of the approved history/trend scope.

Verify date/week/DST boundaries, canonical/mixed-unit weights, bodyweight metric choice, hidden/draft/correction cases, exact set identities/order, zero/one-point views and failed/canceled navigation. Preserve all existing user edits using an isolated candidate and guarded application. Device VoiceOver/real Dynamic Type execution remains explicit when full Xcode is unavailable.
