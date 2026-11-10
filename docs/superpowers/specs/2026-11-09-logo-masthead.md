# Restrained week masthead

The user approved the restrained left-aligned version: clean transparent logo on the week view, refined spacing, unchanged mark and colors.

Use the existing `docs/brand/senda-logo-transparent.svg` as the exact geometry/color source. Preserve all six paths and their translations. Export a tightly bounded high-resolution transparent app PNG with a small antialiasing safety margin. Retain the original source assets.

Display the full wordmark at 124 × 32 points using aspect-fit, aligned with the 24-point week content margin. Give the logo/month header an explicit 18-point gap; retain the ordinary 16-point gap before the day list. Keep the logo on the week view only, with the Senda accessibility label. Preserve ivory #F7F3EB, terracotta #A94E32, charcoal #302720, Georgia headings and current navigation. No decorative left bars, new dependencies, commits or pushes.

Verify actual alpha/color/bounds, unchanged vector source, native normal/compact/Larger Text renders and existing tests. This is a reversible asset/layout refinement; no new behavioral tests are needed.
