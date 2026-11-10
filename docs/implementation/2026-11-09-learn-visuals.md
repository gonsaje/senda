# Learn visual integration

The library shows small offline form illustrations, with front/back anatomy thumbnails for the five presets without a matching illustration. Row subtitles name the primary muscle regions and equipment. Detail pages show the exact variation, two labeled form positions where available, front/back muscle maps and named roles, then the existing written instructions and coaching source. Tapping a position opens a larger offline view with a description and Done action. Illustration credits include the creator, pinned original source and license.

All 20 presets have qualitative muscle maps; 15 have inspected position pairs. The [anatomy audit](2026-11-09-learn-anatomy.md) and [artwork inventory](2026-11-09-learn-artwork.md) explain the coverage. Custom exercises keep their existing missing-guide state. No workout data, saved classifications, backup schema or logging behavior changes.

## Verification

- Integrated package: 382 tests in 49 suites passed, including 7 anatomical mapping tests and 3 offline illustration tests. All 30 frames decode through the same ImageIO path used by the views, at thumbnail and detail sizes. Unknown resources return nil.
- Native macOS renders reviewed at 393 and 320 points: library, bench detail, posterior-chain and squat maps, enlargement, missing-artwork guides, custom exercise and accessibility text settings. Form positions stack at accessibility sizes. These are real SwiftUI renders, not iPhone simulator captures.
- An independent code and visual review found no remaining substantive issues after the illustration display fix.
- The first native render caught blank plain-resource images despite valid file checks. An explicit ImageIO URL decoder, matching the existing logo's loading approach, fixes display on the Mac preview. The loader downsamples thumbnails and uses a 24 MB cache. Original PNG bytes remain unchanged; display uses multiply compositing against ivory.
- The iOS UI test for opening and dismissing a form position was added and source-parsed. Xcode/iOS runtime is unavailable here, so it was not executed. On-device VoiceOver, Dynamic Type and live modal dismissal still require device validation. The computer-use connection could not attach to the native preview process.
- `git diff --check` passed. Original active-workspace file hashes are checked before a guarded apply; only reviewed feature files are copied.

Preview: run `senda-preview --learn-only /absolute/output/directory` for focused visual review. The normal preview still renders all existing screens. The local gallery now includes Learn full-page and compact views and watches bundled resources as well as source files.
