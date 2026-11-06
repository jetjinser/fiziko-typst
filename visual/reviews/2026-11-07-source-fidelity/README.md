# Visual baseline review — 2026-11-07

The full CI run exposed four snapshots that no longer matched retained source
fidelity changes. I inspected the reference, current render, and amplified
difference for each case before refreshing only those four baselines.

| Case | Previous mean absolute pixel error | Review |
| --- | ---: | --- |
| `figure-11-page-5` | `8.41e-5` | The current render includes the supplied coast on the visible hemisphere. This follows the source-oriented globe projection traced and retained in `0429ac0`; the old page snapshot predates that change. The eye, knot, refraction, caption, and layout remain stable. |
| `tube-longitudinal` | `9.32e-4` | The silhouette and lane shading retain the intended layout; the differences are narrow contour changes from source threshold rounding in `b1e671d`. |
| `tube-variable` | `2.04e-3` | The same source-width threshold correction changes thin contour edges around the variable-radius tube; its overall shape and lane structure remain intact. |
| `stipple-brush` | `1.78e-4` | Sparse dash marks move at a few source width-gate decisions after `4023f1a`/`b1e671d`; composition and placement remain unchanged. |

The updated PNGs were generated with `visual-regression.sh --update` selecting
only these four cases. The other seven visual fixtures were not rewritten.
