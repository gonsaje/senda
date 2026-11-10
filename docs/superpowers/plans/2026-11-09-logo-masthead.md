# Logo Masthead Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for this approved small refinement.

**Goal:** Integrate the existing logo cleanly into the week notebook masthead.

**Architecture:** Render the existing vector paths into a tightly bounded transparent PNG using native graphics libraries, decode it through the app's existing CGImage resource path, and define masthead spacing explicitly.

**Tech Stack:** SwiftUI, CoreGraphics, ImageIO, Foundation XMLParser; no new dependencies.

**Spec:** docs/superpowers/specs/2026-11-09-logo-masthead.md

## Constraints and review focus

Preserve the existing mark, all path transforms, terracotta #A94E32 and charcoal #302720; no opaque background or texture. Keep aspect ratio, antialiased edges, Senda accessibility label and the existing week navigation. Preserve unrelated uncommitted changes. No commits or pushes.

## Task: Asset and masthead

- [x] Add reproducible native vector export in `scripts/render-logo.swift`; generate `Resources/senda-wordmark.png` from the approved master.
- [x] Update `SendaIdentity.swift` to aspect-fit the asset in 124 × 32; group logo/month controls at 18-point spacing in `TrainingNotebookView.swift`.
- [x] Verify alpha, interior colors, geometric bounds and unchanged SVG. Review normal, compact and Larger Text native week renders.
- [x] Run existing tests and review the exact delta.
- [x] Apply only focused files after baseline comparison.

## Verification

- Existing suite: 451 tests in 57 suites passed. Native iPhone simulator build succeeded.
- Transparent asset: 1536 × 383 pixels; 417,583 fully transparent pixels; all four corners transparent; opaque colors exactly #A94E32 and #302720.
- Geometry matches the six approved paths and all translations: artwork bounds (178, 221, 1556, 383.039911). Original vector and PNG files are unchanged.
- Native normal, compact, Larger Text, split-month and split-year previews reviewed; independent review found no visible regression or preservation issue.
- Preview artifacts: `/Users/jaesong/Documents/ChatGPT/senda/output/logo-masthead/after/`. No commits or pushes.

Applied eight focused files to the app repository after baseline comparison; all applied hashes match the verified working copy. Unrelated uncommitted work retained.
