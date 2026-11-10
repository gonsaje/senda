# Automatic set saving

Valid numeric changes now update the same local set immediately, while the number editor remains open. Typing, dial changes, steppers and an explicit Use last values action share the atomic snapshot save. Done normalizes display text and closes the editor; it does not accept or count a set for the first time.

Rows no longer show Empty, Unfinished, Recorded or Unfinished edit statuses. Missing values get field-specific guidance. An incomplete correction can show its last saved values and Restore saved values. Optional set details use Not set, and working-set totals update immediately. The footer reports All changes saved whenever current input has been persisted, including partial input; it shows Couldn’t save changes when a transaction is pending or has failed.

## Data and recovery

The model synchronizes the focused valid row after each transaction update and before validation/persistence. Raw typing strings and focus remain intact; only closing the editor normalizes strings. Existing set/action IDs, original dates, annotations and canonical weights remain intact. Historical kilogram prefill uses canonical values rather than reparsing rounded display text. No schema, backup-format or stored-group changes are required.

Incomplete input is saved as recovery text while the journal keeps the last valid observation. A failed numeric save keeps raw input visible over the previous durable journal; its pending transaction contains the matching complete set. Retry publishes that transaction once. New input supersedes an old failed destination, and entering a metadata editor resynchronizes current valid input without replaying obsolete navigation callbacks.

## Validation

The candidate package passed 395 tests in 50 suites. Thirteen automatic-saving regressions were added, with RED/GREEN runs for the new behavior. They cover focused save and relaunch, corrections/date/identity, raw text, partial values, bodyweight/zero, exact kilogram prefill, steppers, failed writes, retry supersession, metadata entry and footer truthfulness after an error is dismissed. Existing logger tests now expect immediate persistence while retaining failure and incomplete-input protections.

Native SwiftUI previews cover active editing, normal and compact phone sizes, accessibility text settings, partial corrections, save failures and successful retry. These are macOS renders, not on-device iPhone verification. Updated iOS UI acceptance tests were source-parsed; an iOS runtime is unavailable here. `git diff --check` passes. An independent read-only review found no P1/P2 issues in the transaction or UI changes.

For focused preview, run `senda-preview --autosave-only /absolute/output/directory`. The local gallery leads with the updated set-editing screens. The active workspace is updated only after original-file hash checks and reviewed-file validation; the applied package is checked again afterward.

Applied-package verification also passed 395 tests in 50 suites. Fresh actual-app autosave renders and the live preview were checked after applying the reviewed files.
