# Daily logging second pass

November 8, 2026

This pass addresses the next-set, exercise-selection and previous-workout recommendations from the UI and UX audit, plus discoverability of hidden recorded work.

## Daily entry

New set reuses an untouched blank final row and keeps its identity. Blank rows can offer Use last values, derived from an actual preceding recorded row or a strictly earlier training day. It fills an editable draft only after a deliberate tap. Canonical unit conversion, bodyweight and zero values remain exact; performed history changes only at the existing completion boundary.

## Exercise setup

The chooser defaults to all muscle groups. Search and selected group/equipment constraints intersect consistently. Recent choices come from performed history and keep unique identifiers; compact filters leave them easy to reach. Single-add remains available, while Select several applies the ordered choice in one transaction. Canceled or superseded failed additions cannot appear during later recovery.

Use a previous workout lists earlier days with recorded work and copies their exercise structure. It appends missing tabs, preserves existing destination rows and selects the first newly shown exercise. Source values, performed identities and dates are not copied. Existing first-pass transaction retry and lifecycle rules apply.

Hide tab now describes its real behavior. All includes retained recorded or meaningful unfinished hidden exercises, even after all visible tabs are hidden, and selecting one restores its original rows.

## Verification

Model regressions cover duplicate blank prevention, exact prior-set sources, draft-only prefill, bodyweight/zero and canonical weights, ordered atomic addition, reusable prior-day projection, source immutability, existing destination work, repeated calls, continued write failure, retry, cancellation, hidden custom/legacy work and persisted reopen. Filter tests cover query/group/equipment intersections and stable unique results.

Native review includes recent-picker, compact picker, reusable-workout chooser, new-set values, prefilled draft and hidden-index screens. iPhone interaction tests are extended for all new flows; execution still requires full Xcode and an iOS simulator. Mac-hosted captures do not certify iPhone keyboard, VoiceOver or Dynamic Type behavior.
