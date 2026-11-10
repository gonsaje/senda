# Workout spacing and entry refinement

The user requested a cleaner workout screen and more intuitive set entry, retaining Senda's ivory, terracotta, charcoal and notebook feel. This is a focused refinement of the existing SwiftUI workout, not a different logging model.

Keep the exercise heading, separate set-type column, paired weight/reps, automatic saving and recovery. Replace the unconfigured plan explanation plus Plan button with one Add plan action. Reduce spacing between the workout's sections from 12 to 8 points; compact numeric cells use 48-point minimums and 2-point vertical padding while ordinary and accessibility cells retain their current sizes. All interactive targets remain at least 44 points. Clip the scrolling workout to its layout bounds so it cannot draw behind status-bar text while editing.

The weight editor labels its continuation Reps. While typing, the ruler gives way to the keyboard; a 44-point keyboard-dismiss control returns to the dial without changing the value. The completed last row's reps editor offers Next set alongside Done. It creates an ordinary working set using the existing atomic new-set operation and carries the current typing mode into the next field. An incomplete or unsaved row cannot use that continuation; editing an earlier row does not offer it. Done remains dismissal and never becomes a save requirement. Bodyweight entries continue into reps. At accessibility text sizes, the set context sits above the action row and action labels grow vertically instead of truncating.

Alternatives considered: spacing alone leaves the extra dismissal/navigation step; an inline replacement editor changes too much of the established dial and recovery behavior. The chosen refinement keeps those systems and clarifies the existing progression. No logo, week-view, color, persistence-format or drop-set behavior changes are included.

Verification covers default and compact native iPhone screens, keyboard continuity, incomplete-input gating, earlier-row editing, Larger Text, drop stages and failed-save retry. Preserve unrelated work and do not commit or push.
