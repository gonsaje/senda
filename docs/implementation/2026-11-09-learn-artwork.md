# Learn exercise artwork

Learn bundles 30 original PNG illustrations for 15 of the 20 preset exercise variations. Every accepted pair was visually inspected. These files work offline and have no pixel edits, crops, recoloring or conversion; only their filenames changed.

## Source and credit

- Project: [Everkinetic data](https://github.com/everkinetic/data).
- Creator: Greg Priday / Everkinetic, as identified in the project's [README](https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/README.md).
- Source revision: `446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6`.
- License: [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/), identified by the repository's [full license](https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/LICENSE.md).
- Changes: Original PNGs redistributed without pixel changes; filenames changed for bundling.
- No endorsement by Greg Priday, Everkinetic or Creative Commons is implied.

Keep a visible source credit, creator credit and license link with the illustrations. The license notice and original source links ship with the app in `Sources/SendaNotebook/Resources/ExerciseForms/`:

- `EVERKINETIC-ATTRIBUTION.txt`: creator, source revision, license link and changes notice.
- `EVERKINETIC-LICENSE.md`: the complete original CC BY-SA 4.0 license text.
- `EVERKINETIC-MANIFEST.json`: one record per bundled PNG, including source path, pinned source URL, phase, exercise ID and SHA-256 checksum.

The artwork remains available under CC BY-SA 4.0. Keep these notices and source information when redistributing it. The app's exercise instructions retain their existing sources; Everkinetic credits apply to the illustrations.

## Coverage and review

The source-file column lists paths relative to `src/images-web/` in the pinned repository. All accepted PNGs are unmodified copies of those files. A source filename's number does not reliably indicate movement order; the catalog supplies the correct displayed phase labels.

| Preset ID | Included variation | Original source files |
| --- | --- | --- |
| `bench` | Flat barbell bench press | `bench-press-1.png`, `bench-press-2.png` |
| `deadlift` | Barbell deadlift | `barbell-dead-lifts-1.png`, `barbell-dead-lifts-2.png` |
| `squat` | Barbell back squat | `barbell-squat-1.png`, `barbell-squat-2.png` |
| `row` | Unavailable | The available illustrations depict reverse-grip or rear-deltoid rows, with a different grip or arm path. |
| `overhead-press` | Unavailable | The available barbell illustration is seated; this guide specifies standing. |
| `lat-pulldown` | Unavailable | The wide-grip illustration places the bar behind the neck. This guide specifies the upper chest. |
| `romanian-deadlift` | Barbell Romanian deadlift | `romanian-dead-lift-1.png`, `romanian-dead-lift-2.png` |
| `dumbbell-bench` | Flat dumbbell bench press | `bench-press-dumbbell-1.png`, `bench-press-dumbbell-2.png` |
| `pull-up` | Overhand pull-up | `pull-ups-1.png`, `pull-ups-2.png` |
| `leg-press` | Inclined leg press | `leg-press-1.png`, `leg-press-2.png` |
| `leg-curl` | Lying machine leg curl | `lying-leg-curl-machine-1.png`, `lying-leg-curl-machine-2.png` |
| `leg-extension` | Seated machine leg extension | `leg-extensions-1.png`, `leg-extensions-2.png` |
| `lunge` | Forward dumbbell lunge | `dumbbell-lunges-1.png`, `dumbbell-lunges-2.png` |
| `biceps-curl` | Unavailable | The seated dumbbell illustration uses a flat bench; this guide specifies a backrest. |
| `triceps-extension` | Cable rope pressdown | `triceps-pushdown-with-rope-and-cable-1.png`, `triceps-pushdown-with-rope-and-cable-2.png` |
| `lateral-raise` | Standing dumbbell lateral raise | `lateral-dumbbell-raises-1.png`, `lateral-dumbbell-raises-2.png` |
| `calf-raise` | Calf press on leg-press machine | `calves-press-on-leg-machine-1.png`, `calves-press-on-leg-machine-2.png` |
| `hip-thrust` | Unavailable | No matching barbell hip-thrust illustration was found in the reviewed source. |
| `cable-row` | Seated cable row | `seated-cable-rows-1.png`, `seated-cable-rows-2.png` |
| `push-up` | Floor push-up | `push-ups-1.png`, `push-ups-2.png` |

The leg-curl images show a lying machine, the lunge images show dumbbells and a forward step, the triceps images show a rope attachment, and the calf images show ankle movement on a leg-press machine. These details were checked against the written variations.

No substitute artwork is returned for the five unavailable variations. Their written guides and muscle maps remain usable. ACE photographs and generated artwork are not included.

## Integration

`ExerciseFormVisual.guide(for:)` in `Sources/SendaNotebook/ExerciseFormVisualCatalog.swift` returns the variation label, ordered frames, accessibility descriptions and attribution metadata. Each frame's `resourceName` omits `.png` and resolves from the notebook module's resource bundle. Unknown and unavailable exercise IDs return `nil`.

`ExerciseFormVisual.all` contains the 15 accepted entries. Each contains two frames with a phase label that describes the actual pose. The app should display the variation label alongside the visual and preserve the source and license links.
