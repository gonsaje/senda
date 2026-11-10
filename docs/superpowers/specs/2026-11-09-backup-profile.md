# Backup, restore and on-device profile

The user approved the next audit pass: UX06 complete backup/validated restore and UX16 truthful on-device profile language.

## Behavior
- Settings offers a complete Senda JSON backup and a readable performed-set CSV. JSON includes exact journal identities, dates, custom exercises, training order, units, unfinished input and local profile details. Stored legacy email remains compatible but is no longer requested or displayed. CSV is for reading, not restoring.
- Choose a JSON backup, validate it without writes, then review its creation date, training days, performed sets, custom exercises, unfinished rows and units. Restore replaces rather than merges; it requires a final in-app confirmation. Invalid, oversized, incompatible or canceled input changes nothing.
- Retain a complete pre-restore backup, reachable through Settings. Before replacing either journal or profile file, persist original bytes in a pending transaction marker. Failed or interrupted restores roll back both original files before normal opening; a failed rollback keeps the marker and blocks opening/writes.
- If the journal cannot open, offer raw original-file export and the same validated backup recovery flow. Raw originals are preserved even when they cannot be decoded as a Senda backup.
- Your details contains an optional name, preceded by a local-storage explanation. Settings explains no account or automatic sync is provided, units apply to progress/new workouts, and backup files can be saved through the system Files interface.

## Approach and constraints
Use a versioned archive codec and a separate restore store alongside existing repositories. This preserves ordinary logging transactions and gives the two-file replacement a durable rollback boundary. A direct pair of independent saves was rejected because a crash could leave partial restoration. Sync/cloud accounts, merging journals, progress charts and routines are outside this pass.

Swift6, iOS17+, macOS14, no new dependencies. Keep Senda ivory/clay/ink colors and Georgia headings. No real personal journal is imported or replaced during development. Changes are developed in an isolated snapshot preserving the live branch's uncommitted work, then guarded by file hashes when applied.

## Acceptance
Roundtrip exact data and drafts; export creates no performed sets. Failure at each restore stage, including startup recovery, preserves originals or blocks opening until recovery succeeds. Preview and cancel never write. Repeated restore cannot replay old logging retries. Native compact layouts remain readable; iPhone native picker/VoiceOver execution remains an explicit environment limitation if Xcode is unavailable.
