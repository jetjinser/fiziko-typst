# Source-fidelity baseline and follow-up plan

## Baseline

The paired report covers the pinned upstream revision
`54a63dba8e6700a5e70d3508838edebcbf0f45fe`: historical plates M1–M11 and
S101–S108, plus isolated sphere C1. The latest full report is generated at
`build/source-parity/index.html` with:

```sh
nix develop path:./nix --command ./compare.sh --mode nominal --ppi 600 --output build/source-parity
```

This run completed 20/20 plates. MetaPost and Typst PDFs use the same pinned
Ghostscript grayscale rasterizer at 600 ppi, with no image registration or
rescaling. The report keeps each source PDF, Typst PDF, raster, amplified
difference, full-frame metrics, declared component crops and input hashes.
RMSE is normalized to 0–1. Ink/dark coverage helps reveal missing or excess
marks, but neither it nor RMSE establishes shape similarity on its own. Review
the paired images and compare crops only with the same dimensions and renderer.

The added pairs use nominal, source-mapped dimensions and control points.
Their `calibrated` values currently equal `nominal`; they are not fit to the
source plates. Existing M2 calibration changes its width law, so its calibrated
score must not be presented as equal-parameter fidelity.

## Added plate results

Full-frame dark coverage is reported as source → Typst. Component results are
included where a plate contains distinct drawing families.

| Plate | RMSE | Dark coverage | Component findings |
| --- | ---: | ---: | --- |
| M8 pulley composites | 0.16877 | 1.778% → 3.276% | Left and right figures are both over-inked, with crop RMSE 0.18759 and 0.15045. |
| M9 wood panels | 0.29579 | 4.349% → 7.570% | All four panel crops score about 0.291–0.300 RMSE; the port's smooth field does not reproduce the source's irregular knot-driven grain. |
| M10 mechanics and optics | 0.08506 | 0.672% → 0.823% | Spring/weight crop RMSE 0.11766; lens/rays 0.06302. |
| M11 globe, eye, knot, refraction | 0.24449 | 5.013% → 3.194% | Globe crop: RMSE 0.49895 and dark coverage 26.446% → 8.069%. Knot crop: RMSE 0.30447 and ink coverage is 3.079× the source. Eye: 0.23617; refraction: 0.08193. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.22142 | 3.240% → 3.635% | At 600 ppi opaque RMSE 0.33901 with near-equal coverage (8.738% → 8.699%); gradient RMSE 0.33668 and coverage 6.901% → 6.917%. Glass remains over-inked (3.638% → 5.683%; RMSE 0.26279). |
| S104 flat surfaces | 0.32819 | 10.630% → 9.745% | At 600 ppi stipple coverage now matches (7.079% → 7.121%, RMSE 0.28549). Hatch is still under-dense (14.066% → 12.284%, RMSE 0.36477); overall RMSE regressed from 0.29890 despite better density balance. |
| S105 wood block and surface | 0.13445 | 0.768% → 1.531% | Block crop is near source coverage (1.111% → 1.207%); wooden-surface crop is over-inked (0.511% → 1.841%). |
| S106 weights | 0.10910 | 1.162% → 0.805% | Standing weight crop 1.692% → 0.853%; hanging weight 1.208% → 0.986%. |
| S107 wheels and centroid | 0.18217 | 3.260% → 2.575% | Pulley wheel is over-inked (3.949% → 5.796%); the open-spoke wheel is under-inked (7.319% → 2.739%); centroid crop RMSE 0.05441. |
| S108 lenses and annotations | 0.10093 | 0.476% → 0.890% | Lens crop RMSE 0.12716; arrow/angle annotation crop 0.08729. |

These whole-plate RMSE values are useful for locating large residuals, not for
ranking unlike subjects as if the scores were a universal similarity scale.
M11's globe crop, for example, combines a large shaded region with coastline
strokes, while M10 contains mostly whitespace.

## Recommended implementation order

1. **Reproduce MetaPost's seeded random stream and draw-call order.** The
   default scaled stream now has a fixed-seed oracle and an opt-in pilot for
   `sphere-latitude`. The M3 nominal RMSE fell from 0.07233 to 0.07143, while
   dark coverage moved from 0.01% above the source to 0.69% below it; rendering
   took 47.6 s versus 40.3 s. The improvement is real but modest, so the
   library default remains keyed. Continue by threading the stream through a
   brush, one stipple family and wood, checking their source call order before
   considering broader defaults.
2. **Bring the wood field closer to `woodBlock`.** The first port now uses the
   source's knot-warped scalar field, 1 mm sample grid, and rotated panel axes.
   At 600 ppi M9 whole-plate RMSE fell from 0.29579 to 0.24594; each panel
   crop improved from 0.292–0.300 to 0.240–0.252. M9 ink coverage moved from
   7.17% to 5.57%, closer to the source's 4.20%. S105 block RMSE fell from
   0.14057 to 0.13129; coverage shifted from 1.14% to 1.17% (source 1.08%).
   S105's separate wooden surface is unchanged and remains over-inked. Knot
   placement is reproducible but currently uses per-panel seed offsets rather
   than consuming the exact upstream global call stream; contour pen widths
   are approximated, and the wood-knot outlines are not yet source brush loops.
   Next, port the source's contour-width modulation and shared RNG cursor,
   then tackle `woodenSurface` separately.
3. **Reconcile `flatSurface` and the S103 fill families.** The port now uses
   upstream stroke/row scales, the lightness envelope and three-track stipples.
   At 600 ppi S103 whole-plate RMSE improved from 0.23772 to 0.22142, and its
   opaque and gradient ink coverages now closely match. S104 stipple ink
   coverage moved from 1.19% to 7.12% (source 7.08%), but the hatch remains
   under-dense and S104 whole-plate RMSE rose from 0.29890 to 0.32819. Glass
   remains over-inked. Further work should compare row placement and edge
   clipping, then isolate glass width and hatch allocation rather than changing
   global fill density.
4. **Split M11 into faithful globe and knot renderers.** The comparison now
   supplies the exact eight upstream coast paths, but the public `globe` draws
   coast strokes and a graticule where the source clips shaded latitude marks
   to land. Port that shading/mask behavior first. Then match the source knot
   over-under sequence; its current crop has roughly three times the source
   ink. Keep eye and refraction as separate component gates.
5. **Tune the mechanical details from local crops.** After the cross-cutting
   algorithms, work on M8 pulley/rope strokes and S107 rim, groove and spoke
   shading. M10 and S102 are closer by full-plate measures and can remain
   lower priority unless visual review finds a specific defect.

At each step, keep a same-input nominal comparison, review the difference
image, and record geometry, dark coverage and ink coverage together. Keep any
visual-only parameter calibration in its own mode. The Typst-only pixel
regression suite remains a change detector; source parity is measured by
`compare.sh` and reviewed source/Typst/difference images.
