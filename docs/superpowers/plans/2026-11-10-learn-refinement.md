# Learn refinement implementation plan

**Goal:** Make finding, reading and returning from an exercise guide feel consistent with the refined notebook screens.

**Scope:** `TrainingLearnView`, `ExerciseLearningDetail`, Learn preview fixtures, focused iPhone interactions and the Learn README description. Keep domain content, artwork, anatomy, licenses, model, storage, workout, week, Trends and branding unchanged.

**Spec:** `docs/superpowers/specs/2026-11-10-learn-refinement.md`.

- [x] Inspect current native and rendered screens; read project design/copy guidance and independently audit Learn.
- [x] Add focused native search/return/empty-state and compact Largest Text checks before product edits.
- [x] Refine search recovery, row alignment, guide typography, scroll restoration and adaptive illustration controls.
- [x] Diagnose baseline failures: the navigation container overrides Back's identifier; the illustration close test incorrectly calls an existence-asserting helper to assert absence. Preserve both navigation identifiers with explicit containment and use a direct wait-for-absence assertion after Done.
- [x] Review fresh regular, compact, custom, anatomy-only and Larger Text renders; pass full semantic and focused native checks.
- [x] Obtain independent final review; apply only baseline-checked files and verify destination hashes/whitespace.

Spacing and copy receive visual review rather than tests that mirror layout. Interaction checks cover search recovery, query and row-position restoration, guide entry at the title, and accessible illustration dismissal. Keep logs, captures and the application manifest under the review workspace's `output/learn-refinement`.

## Verification

The full semantic suite passes 455 tests in 57 suites. Native iPhone 16 checks pass for searching, clearing the query, empty-state recovery, opening a result after scrolling, starting the guide at its title and returning to the selected row. Illustration enlargement/Done and the existing unfinished-workout/profile recovery flow pass as well. The compact iPhone 13 mini passes the same search/return case, plus Largest Text search/illustration dismissal and dock navigation. Final Larger Text captures verify the adaptive illustration header and quiet fixed-size decorative glyphs; all text and control targets retain their growth.

The initial form-dismiss test had an existence-asserting helper inside an absence assertion. Its direct wait-for-absence replacement passes; no viewer dismissal bug was found. Back did have a parent identifier propagation problem, fixed with explicit accessibility containment. A compact run stalled for about 933 seconds while XCTest synthesized an upward library scroll. Its captured app/window/scroll frames were normal and Hip thrust was above the dock; the unchanged isolated case passed in 23.1 seconds. No test-helper or app workaround was added for that event transport timeout.

Fresh renders cover the library, search, empty results, mixed custom/preset results, illustrated guides, an anatomy-only guide, a custom guide and the enlarged viewer at ordinary, compact and Larger Text sizes. Existing instruction text, anatomy data/drawings, artwork, links and licenses remain unchanged. The shared bottom dock is outside this pass; the Largest Text capture retains its existing label wrapping.

Independent final source and visual review closed without actionable findings, including a follow-up review of decorative glyph sizing. Concurrent day-header preview additions were retained unchanged; the focused Preview diff only extends Learn fixtures. Applied seven focused files after baseline checks and verified matching destination hashes and whitespace. The patch and manifest are in the review workspace. No commit or push.
