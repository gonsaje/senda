# Xcode keyboard and accessibility validation — November 9, 2026

Xcode setup is complete. The follow-up workout pass resolves the accessibility findings: eight final workout audits pass on iPhone 13 mini and iPhone 16. See [the follow-up validation](2026-11-09-workout-accessibility.md) for the final changes, results and remaining physical-iPhone VoiceOver check.

## Environment

- Xcode 26.6 (17F113) is the selected developer installation. First-launch status succeeds.
- iOS 26.5 (23F77), arm64 simulator runtime is available. Dedicated iPhone 13 mini and iPhone 16 test devices were used.
- Simulator and unsigned physical-iPhone builds succeeded. No signing account, provisioning profile or physical-device installation was changed.
- UI tests use unique debug journals. Real user journal data was not used or reset.

## Changes

- Essential logger, plan, editor and filter actions use their full existing touch frames.
- At accessibility text sizes, picker title/search/filter tools scroll beneath pinned actions, keeping the keyboard flow usable. Selected order badges scale with text.
- Long set-type definitions remain readable separately from the choice button at accessibility sizes. Close stays pinned.
- The dock allows multiline labels. Step controls expose current values and full units. Reps-left options expose selection, and repeated invalid profile saves announce the error.
- Transparent container identifiers no longer replace child identifiers. Read-only table headings remain accessible without inheriting row interaction.
- On iOS 18+, a direction-gated native pan rejects vertical movement before the row swipe begins. Vertical scrolling now works when a drag starts on a set row; short reveal, full delete and Undo still pass. The existing iOS 17/macOS gesture remains; iOS 17 runtime behavior was not tested in this pass.
- The test runner accepts focused test arguments and can find the standard full Xcode installation when standalone command-line tools are selected.

## Initial verification

- Final semantic suite: **451 tests in 57 suites passed**.
- Final simulator test build and unsigned physical-iPhone build succeeded.
- iPhone 13 mini: the 19-case run passed 17 and failed two. One failure was a test tap hitting a pinned filter footer rather than the offscreen Cable chip. After correcting filter visibility bounds and minimum scroll travel, all three targeted picker checks passed on the final badge implementation. This leaves **18 unique focused checks passing and one populated-workout audit failing**.
- iPhone 16: both largest-text logger checks, ordered multi-selection, row swipe/delete/Undo, and the final three picker checks passed. The populated-workout audit still fails.
- Verified flows include direct Next-to-reps keyboard focus, Done dismissal, Search Return, opening filters with the keyboard present, custom-exercise cancellation, decimal typing/dial input, autosave, grouped Drop sets, stepper values and reps-left selection.
- Default all-type accessibility audits pass for the exercise picker, filters, Profile and backup settings on the compact phone; final picker/filter audits also pass on the larger phone.
- Exact keyboard and final badge screenshots were reviewed at the largest accessibility text size. No audit type or issue was ignored. The audit handler records details and returns false for every issue.

## Findings closed in the follow-up

1. The mini’s potentially inaccessible workout text is resolved with readable adaptive labels and native set-type and Undo controls.
2. The larger phone’s partially unsupported Dynamic Type finding is resolved by preserving the New set/Repeat action tree as its layout changes.

The expanded audit also exposed date-name and save-status issues. The follow-up resolves them and verifies empty, blank, populated and repeated-set states with every audit category enabled.

A physical-iPhone VoiceOver pass remains outstanding, deferred at the user's request to finish Xcode work first. Automated audits do not substitute for spoken focus/order, rotor, announcements or real-device keyboard testing.

## Integration and evidence

The actual repository changed independently during this pass. A fresh 704-file baseline was captured and the changes were merged without replacing the newer plan/reference/history work or six new files. The final apply checks all baseline hashes, copies only the reviewed files, verifies their hashes and checks unrelated originals again. No commits or pushes.

Evidence is saved under `/Users/jaesong/Documents/ChatGPT/senda/output/iphone-keyboard-accessibility/`. Machine-readable summaries name the original result bundles under `/private/tmp/senda-iphone-results/`; earlier failed runs are retained there for traceability.
