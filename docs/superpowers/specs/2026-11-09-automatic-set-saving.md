# Automatic set saving

The user wants weight and rep updates to save automatically and no recorded/not-recorded status. Every complete valid update must reach local storage immediately, without Done, navigation or a separate acceptance action. This includes typing, dial adjustments, steppers and an explicit Use last values action. Done closes the editor.

Retain focused raw strings while typing. Partial or invalid text remains durable recovery input; it never becomes an invalid observation. An incomplete correction preserves the set's last valid values and identity. Keep historical dates, canonical weights, annotations, idempotent inserts, delete/undo and backups compatible. No schema change is needed.

Use the existing atomic snapshot transaction, synchronizing a valid focused row before persistence on every user transaction. On numeric write failure, keep the raw edited row visible with the old durable journal and retain the complete pending transaction for Retry. Later input replaces the obsolete transaction; metadata edits can retry current valid numeric values without replaying a failed navigation destination.

Remove status labels and recording-step language from the rows, number editor and set-details fields. Retain field-specific guidance and actual save-error recovery. Keep the existing brand, flat layout, essential 44-point targets and Larger Text support.
