# Backup, restore and on-device profile

November 9, 2026

## Complete notebook ownership
Settings exports a versioned Senda JSON archive or readable recorded-set CSV. JSON retains the complete validated training snapshot and local profile, including previously stored email for compatibility while removing its collection/display. Required format/version/library/training fields reject incomplete archives; imports and exports are bounded at50MiB. Exact numeric Date and canonical weight representations preserve the original data. CSV includes performed sets only, exact pound/kilogram values, linked local workout dates, recorded timestamp and IDs, with standard escaping and formula-prefix protection.

Import uses a security-scoped, bounded regular-file read and validates away from the main actor. Its preview shows creation date, recorded days/sets, custom exercises, unfinished input, preferred units and name. Final confirmation replaces rather than merges. Cancel/validation failures never call restore. Native import/export follow [Apple’s fileImporter documentation](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:oncancellation:)) and [fileExporter documentation](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)).

## Recovery boundary
The production FileNotebookRestoreStore writes a durable original-pair marker before replacing either journal or profile, and removes it only after both writes succeed. Failure and startup recover both raw files (or their original absence); failed rollback retains the marker, blocks ordinary logging and hides the dock until recovery succeeds. App and live-preview composition pass the file store before opening the notebook or profile.

The latest pre-restore copy is accessible in Settings: a complete archive when current data can be validated, otherwise a raw original-pair recovery file, explicitly labeled as non-importable. Copy-kind cleanup prevents an older archive hiding a newer raw recovery point. Opening-error recovery can export the original current journal unchanged before replacement. An unreadable profile causes visible draft recovery to be persisted before raw protection; a failed write blocks replacement. Persisted-baseline bookkeeping is updated even when later restore fails. Successful restore clears old failed logging/profile callbacks and normalizes legacy exercise registration as normal opening does, so hidden history is immediately reachable.

## Profile
Your details asks only for an optional name, with its local-storage explanation before the field. Name-only saves preserve legacy profile data without requesting it again. Profile exposes preferred units directly; Settings explains those units apply to progress and new workouts. Existing workout units remain intact.

## Verification
Test-first codec, real temporary-file store and model/session regressions cover exact snapshots, unfinished input, invalid/oversized files, dates including retained Undo, failures at every write boundary, corrupt/missing originals, interrupted recovery, protected copy export, stale retries and immediate legacy-exercise access. Full suite and applied-file verification results are recorded in the delivery artifact.

Native SwiftUI renders cover normal/compact Settings, Your details and the validated summary. iPhone system Files interactions, VoiceOver and real Dynamic Type remain to be executed with full Xcode/device; this machine has Command Line Tools. No real user notebook is restored during development.
