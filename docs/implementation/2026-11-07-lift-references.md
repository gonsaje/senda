# Top set, PR, and common working reference

Keep the existing native notebook, set rows, recovery, dual units and direct weight dial. Simplify the previous-entry reference to date plus a single top set. Beneath the exercise name, show one restrained terracotta reference band with the lifetime PR and common working set. These are computed from performed history only and respond to save, correction and undo. Preserve the original architecture and planning documents.

## Decisions

- Top set and PR use heaviest weight, then highest reps at that weight; exact ties use the latest occurrence. This is the implementation default while the optional ranking question is open. No estimated-strength formula or predicted record.
- Last-entry line: date and that entry's top set, with no Last prefix or batch size. It remains tappable to correct the underlying entry.
- PR: the selected exercise's all-time best performed set. Its row opens the source entry for correction.
- Common: the weight appearing in the most performed sets. A frequency tie favors the most recent occurrence. Require at least two sets at that weight before calling it common. At that load, use the middle half of ordered rep counts, rounding the lower/upper quartile positions outward to observed values. Show a single rep count when equal, otherwise a range. This gives repeated values influence and limits isolated rep outliers, without inventing fixed training bins.
- Both units remain visible. Keep the reference band compact, using meaningful PR/Common labels and no celebratory overlay or additional dashboard.
- Empty history has no invented PR or common reference. Pending entries/corrections and failed writes do not alter either value.

## Approach

Compute pure projections from Journal, rather than persist or cache a second statistics store. This keeps corrections and undo authoritative and requires no schema migration. Estimated one-rep maximum and fixed rep-range categories were considered; they add inference or arbitrary boundaries to a factual logging surface.

## Implementation plan

1. Add failing domain tests for top-set ordering, exercise isolation, ties, frequency/rep range, outliers, sparse history, corrections and undo. Add a logger test proving unfinished/pending changes and failed writes do not change the references.
2. Add the domain projection in ExerciseHistory.swift and expose it through LoggerModel. Keep persistence unchanged.
3. Replace the Last sentence with date/top set; add the compact PR/Common band below the name. Keep older-entry editing independent of current input.
4. Update native renders and iPhone interaction coverage, including empty history, committed-only PR and correction/undo behavior. Run the full unit suite, inspect regular/compact SwiftUI renders, request independent review, and run both iPhone checks on the development branch.
