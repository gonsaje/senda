# Notebook refinement — design and implementation

Keep Senda's personal journal character and current local logging behavior. This is the requested typography, spacing, brand and interaction refinement. The supplied three-panel image is visual context; calendar navigation, an exercise-order screen and a new history browser are outside this pass. Existing Last/PR banners and the lb/kg header switch remain.

## Direction

Use Georgia for warmer, more individual serif headings, paired with the existing crisp system sans and tabular numerals. Keep ivory #F7F3EB, terracotta #A94E32 and charcoal #302720. A muted olive #626854 belongs to the redrawn S-path and quiet successful-save feedback. Secondary reference information is neutral. Terracotta identifies exercise selection, Today and actions.

Compared approaches: retaining the current default serif would preserve the formal tone identified in the feedback; bundling a new external font would introduce licensing and asset work before its value is established. Use the built-in Georgia family for this reviewable refinement. Keep the native SwiftUI implementation and draw the tapered S-path as editable vector geometry, with a matching standalone SVG. The canonical original mark remains unavailable; this is a new drawing for review.

Compact the day header into a navigation/date row and a smaller weekday with Today on the same line. Use lighter half-point separators and space rather than strong borders. Preserve distinct, neutral Last and PR surfaces. Keep 44-point controls, readable numbers and large-text layouts.

New/repeated rows enter with a brief opacity/position transition. A successful repeat briefly highlights only its new row in muted olive. Actual journal changes after successful saves trigger a quiet saved check; focus, recovery keystrokes, loading and failed writes do not simulate performed-set saves. All effects honor Reduce Motion; no pulse or animation is persisted.

## Plan

- [x] Add shared typography, lighter rules and native S-path/wordmark; supply the SVG.
- [x] Refine Week, Day and picker typography/spacing and compact the date header; retain accessible identifiers and existing actions.
- [x] Add local row/repeat/save responses, cancellation-safe timers and Reduce Motion behavior; keep domain and persistence unchanged.
- [ ] Render and inspect actual SwiftUI week/day/picker/compact/repeat states. Check the live preview and run the existing 133-test suite, app typecheck and iPhone flows.
- [ ] Review the completed changes, address material findings, and push the finished branch.

Review focus: narrow phones and large text retain header/action access; failed commands never highlight or claim success; revisiting another exercise clears transient highlights; repeated rows retain identity and Undo; Reduce Motion avoids positional movement and automatic scrolling animation.
