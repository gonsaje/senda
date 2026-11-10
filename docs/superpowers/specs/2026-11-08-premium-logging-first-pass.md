# Senda premium logging first pass

The user approved the first implementation pass from the November 8 UI and UX audit: recording states, failed-save recovery, date and resume clarity, and the adaptive editor. Preserve the approved notebook identity and current local-first SwiftUI architecture.

## Recording rules

- Existing performed values and identities remain in history while a correction is incomplete. Preserve that draft across navigation, persistence, interruption and relaunch. A later valid completion updates the same performed set; Discard edit restores its last performed values.
- New incomplete input remains unrecorded. Empty untouched rows are distinct from meaningful unfinished input. Complete new rows still record at the existing Done/navigation boundary.
- Show quiet, local state labels and an actionable explanation where a row needs input. Week shows resumable meaningful unfinished work without adding it to performed totals.
- Preserve exact canonical weights, lb/kg conversion, bodyweight handling, stale-focus protection, explicit deletion, repeat and Undo semantics. Validation must continue rejecting broken references; legacy files remain readable.

## Save recovery

- A visible retry repeats the failed transaction and any associated destination/context change. It must actually attempt persistence even while writes keep failing. It cannot merely clear the error.
- Retries are idempotent; repeated retry cannot add duplicate performed sets. New intentional input supersedes obsolete retries, and background recovery must not silently discard a pending intended action.

## Date and entry presentation

- On a historical or restored previous day, show its historical context and a direct Go to today action. Preserve old drafts in their original dates. Never automatically move input to today.
- During active editing, compact secondary headings/reference banners to keep useful row context in view. Always label the field and weight unit.
- Important entry numerals scale with Larger Text. Use a stacked row/editor layout at accessibility sizes rather than shrinking essential values. Core actions have at least 44 by 44 point targets.
- Add meaningful headings, row state accessibility labels, deliberate editor accessibility focus and concise error/outcome announcements. Respect Reduce Motion in the active ruler.

## Model interfaces

- public enum TrainingRowStatus: Equatable, Sendable { case empty, unfinished, recorded, pendingCorrection }
- public func rowStatus(for row: TrainingRow) -> TrainingRowStatus
- public func recordedValues(for row: TrainingRow) -> SetValues?
- public func discardCorrection(_ rowID: UUID) -> Bool
- public func unfinishedSetCount(for day: TrainingDay) -> Int
- public var canRetrySave: Bool
- public func retrySave() -> Bool
- public func openToday() -> Bool

The model implementer may add an optional persisted correction marker to TrainingRow and validation only as needed; it must decode older snapshots without loss. Every behavior above requires a regression test. UI implementation consumes the interfaces above without editing domain/model sources.

## Scope

This pass does not implement export/restore, routines, historical charts, redesigned Learn, or hidden-exercise behavior from later audit items. Do not regenerate or restyle the approved logo. Source changes remain staged in an isolated candidate until review and verification pass, then are applied to the app with concurrent-change guards.
