# iPhone validation pass

The user selected iPhone build and interaction tests as the next development priority. Preserve the approved notebook direction, planning documents, domain/persistence split, and local-only app behavior.

## Approach

Keep the fast Swift Testing suite, add a real Xcode UI-testing target, and run both on a GitHub macOS runner with Xcode. This machine still has only Command Line Tools, so a host SwiftUI build cannot substitute for an iOS build. Use the existing sample mode for UI flows and a unique debug-only journal location for relaunch persistence tests; never reset or use the real journal in a test.

The numeric stepper currently reads committed draft values while valid typed text is buffered. Move stepping to the logger model so it resolves the full typed value plus the step as one intent, then changes the draft exactly once. Invalid input stays unchanged until corrected or cancelled. Regressions must cover weight, set-count exceptions, limits, and invalid input. The Record label must show the full pending set count before save.

## Plan

1. Add failing model tests for stepper behavior, implement the step operation, and wire the dock to it. Run the complete unit suite.
2. Add `SendaUITests` to the Xcode project and normal scheme. Exercise draft/recorded state, pre-save exception confirmation/cancellation, correction, undo, identical another-batch save, keyboard-visible recording, and actual file persistence after relaunch. Use accessibility identifiers and assertions on visible values.
3. Add a simulator runner script and GitHub Actions checks. Discover an installed iOS runtime instead of assuming a runtime version; retain test result bundles, including screenshots on failure. Document how to run these same checks locally.
4. Verify project/scheme structure, host compilation and all unit tests. Push the development branch and inspect actual iOS results where GitHub Actions is available. Fix failures before treating simulator validation as complete. Keep changes off `main` until reviewed.

## Evidence and limits

- Baseline: 28 tests pass; `main` and `origin/main` start at `8969a81`.
- Working branch: `codex/iphone-validation`.
- No full Xcode or simulator is installed locally.
- Apple documents [XCTest UI tests](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project) as tests that drive the application's controls; these complement the existing domain/state tests.
- GitHub's [macOS runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) supplies Xcode and iOS simulator runtimes. CI validates the app without adding any backend or sync to Senda.
- Reproduced and fixed the full-Xcode path in `test.sh`: the stock macOS Bash 3.2 rejects an empty array expansion under `set -u`. Both developer-tool paths now invoke Swift directly.
- Pinned the set editor's Cancel action above scrolling rows, preserving access on compact phones.
- Read-only review caught the two-step resize truncation, a weak identical-batch fixture assertion, and a Release-build storage-isolation risk. Added a failing atomic-step regression, used a unique weight in the UI fixture, and skip the persistence test before launch in Release.

- First actual iOS run: unit checks passed. The compact-phone build failed before tests because the app built arm64 and x86_64 while Swift package dependencies built only the active simulator architecture. Set Debug `ONLY_ACTIVE_ARCH = YES`, matching the standard Xcode Debug configuration and the dependencies; keep Release architecture settings unchanged.
