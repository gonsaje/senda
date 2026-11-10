# Premium logging first pass

November 8, 2026

The first audit implementation pass makes recorded history independent of an unfinished correction, retries the actual failed transaction, makes historical days and meaningful drafts visible, and adapts the editor to small screens and accessibility text sizes.

## Data behavior

A row can be empty, unfinished, recorded or an unfinished correction. An optional persisted correction marker allows raw partial input to differ from the linked performed values after focus moves, while validation still requires a live, unique performed reference. Existing snapshots without the marker remain readable. Completing a valid correction retains the performed set identity. Discard edit restores its last recorded values.

A failed transaction retains its candidate snapshot and success effects, including section/reference navigation. Retry attempts the same write and publishes its state only on success. New intentional edits replace obsolete failed intent; background suspension preserves pending intent. Performed totals never include new drafts.

## Presentation

Day rows explain their state, pending corrections show their recorded values and offer Discard edit, and the week distinguishes meaningful unfinished work from untouched empty rows. Historical and future days offer Go to today without moving old drafts.

The active editor retains the field and unit, reduces secondary context, scales entry numerals, and uses stacked rows at accessibility sizes. The visual ruler gives way to typing and generous steppers at those sizes. Heading semantics, editor accessibility focus, outcome feedback and Reduce Motion handling are included.

## Validation

Regression coverage targets retained history and identities, relaunch, invalid/valid correction, discard, continued storage failure, repeat retry, superseding input, background suspension, navigation effects, draft counts, bodyweight, unit conversion and date preservation. The native preview renders recorded, unfinished, correction, historical and accessibility layout states. The offscreen host does not advance display-driven focus scrolling, so active-row positioning is verified in the running native preview; static offscreen captures alone do not establish its final scroll offset. The app retains normal animations and honors the system Reduce Motion preference.

The iPhone interaction suite includes correction/discard after relaunch, historical draft resumption after Go to today, and populated large-text entry. These require full Xcode and an iOS simulator to execute. Mac-hosted SwiftUI renders establish the layout behavior available on this machine, not iPhone keyboard or VoiceOver certification.
