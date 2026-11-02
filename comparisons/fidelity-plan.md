# Source-fidelity baseline and follow-up plan

## Baseline

The paired report covers the pinned upstream revision
`54a63dba8e6700a5e70d3508838edebcbf0f45fe`: historical plates M1–M11 and
S101–S108, plus isolated sphere C1. The latest full 600 ppi report is
`build/fidelity-round-2/index.html` (20/20 successful) and can be regenerated
with:

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

Full-frame ink coverage is reported as source → Typst. Component results are
included where a plate contains distinct drawing families.

| Plate | RMSE | Ink coverage | Component findings |
| --- | ---: | ---: | --- |
| M8 pulley composites | 0.11833 | 1.734% → 2.116% | The rope-occlusion silhouette now derives its endpoints from the source support arc's vertical intersections with the outer rim. Shaded-wheel masking is still approximated by draw order. The default figure omits non-source length labels and maps A/B/C offsets to the source; optional `length-labels: true` restores `l` and `m`. At 600 ppi whole-plate RMSE is 0.11833; left/right crops are 0.13227/0.10421. Overall ink coverage remains high. |
| M9 wood panels | 0.22407 | 4.203% → 4.224% | Landscape panels use the source's internal axis swap; accepted knots advance the 28 brush draws, and field offsets now consume once per source 1/3 mm column. Source-traced panel offsets (0, 1456, 2823, 4120) improve later-panel field placement and coverage. The 600 ppi RMSE falls from 0.22412 to 0.22407. Contour-brush shapes remain approximate. |
| M10 mechanics and optics | 0.07533 | 0.645% → 0.810% | Source hanging-weight radius, 1/4 neck, shoulder expansion, 2 mm body offset and a 2*shadingDensity auricle capsule reduce spring/weight crop RMSE to 0.09878 (previous 0.09909); lens/rays remain 0.06302. Auricle interior shading remains approximate. |
| M11 globe, eye, knot, refraction | 0.11483 | 4.917% → 4.792% | `coast-step: 0` connects projected source vertices directly. Coast widths use the source sphere normal/light dot product; globe crop RMSE is 0.19720 and ink 25.940% → 25.213%. The knot fixture now uses 385 source-curve points per strand at 1/16 path-time intervals; knot crop RMSE is 0.05904, down from 0.05979 at 1/8 and 0.06233 at 1/4. Mask mode splits strands at crossing-interval midpoints, orders by source layer, erases prior ink with each higher tube silhouette, and redraws hatch. Crossing detection and tube silhouettes remain sampled/approximate. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.20703 | 10.630% → 10.810% | Mapping source +30° through the fixture's vertical flip gives Typst −30°; reversed row traversal and source-randomized 3–5 path subdivision lower hatch crop RMSE to 0.07650. Unit-aware 16.16 width-level rounding then lowers it to 0.07530, with hatch ink 14.066% → 14.363%. Stipple coverage remains 7.079% → 7.138%. Some brush recursion and local random details still differ. |
| S105 wood block and surface | 0.09837 | 0.741% → 0.601% | Landscape-axis mapping rounds field extents to integer-mm fixture bounds; the source-traced 536-call offset puts the first surface knot within 0.001 mm of the source coordinate. `contour-brush: "cell-range"` uses cLine's per-cell width law with source-scaled 16.16 width levels; field offsets consume once per source 1/3 mm column. At 600 ppi block RMSE is 0.12142 (ink 1.077% → 0.733%); surface RMSE is 0.07644 (ink 0.489% → 0.519%). cLine traversal interpolation and dash calls remain approximate. |
| S106 weights | 0.07663 | 1.091% → 1.106% | Standing crop RMSE is 0.09949 with ink 1.594% → 1.474%. The source-derived hanging profile plus a 2 mm body offset and 2*shadingDensity auricle capsule reduces hanging crop RMSE to 0.06998; ink is 1.131% → 1.263%. Auricle interior shading and tube hatch remain approximate. |
| S107 wheels and centroid | 0.08667 | 3.159% → 2.976% | Both source-style ring renderers now match closely: pulley-wheel RMSE 0.09105 with 3.947% vs 3.833% coverage; wheel RMSE 0.12807 with 6.034% vs 7.100%. Centroid crop RMSE 0.05441. |
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
   library default remains keyed. Longitudinal tubes now have an explicit
   MetaPost-stream mode; source-unit-aware 16.16 thin-brush threshold rounding
   lowers M4 RMSE further from 0.07109 to 0.07025. The same
   transverse RNG pilot worsens M7 from 0.12453 to 0.12532 and is not enabled.
   Sampling the actual M7 spline at 1/8 path-time gives source-shaped geometry,
   but the full transverse render scores 0.12542, so the current comparison
   retains its anchor polyline while dash phase and spacing are unresolved.
   Sampling M4's actual MetaPost spline at 1/8 path-time intervals replaces the
   ideal-circle approximation and lowers its RMSE from 0.07025 to 0.06050;
   source path extraction is reproducible from the pinned driver.
   Boundary-lane marks and exact recursive subdivision still limit the tube
   renderer; a direct M4 boundary-stroke pilot regressed and was reverted
   pending better offset geometry. Brush stipples and further wood call-order
   matching remain open.
2. **Bring the wood field closer to `woodBlock`.** The field uses the source's
   knot-warped scalar field at 0.2 mm detail; Typst contour sampling remains
   1 mm while field offsets now consume once per source 1/3 mm column. A
   1/3 mm contour-grid pilot regressed M9 and S105, so it was reverted. A
   source `cLine` trace now records the recursive `(i,j,st)` traversal; width
   interpolation should follow that sequence rather than geometric segment
   order. Landscape blocks now reproduce the source's
   internal axis swap, and a trace of the pinned source shows that each
   accepted knot consumes 28 random draws in its nested brush rings. Its first
   ring calls are `[14, 6, 6, 2, 0]`; a source-width-knot probe
   on an eight-point polygon gives `[14, 10, 6, 2, 0]`, while denser polygons
   over-subdivide. That polygon is only a count diagnostic; a useful port must
   separate the cubic `fullcircle` geometry from its eight-knot width template.
   The first M9 panel knot now matches source coordinates to under
   0.1 mm; M9 whole-plate RMSE improves from 0.22688 to 0.22456, with ink
   coverage 4.272% versus 4.203%. Contour-brush random calls still leave later
   M9 panel streams approximate. S105 now rounds field bounds to the 1 mm
   source grid and resumes the stream after the traced 536 source calls; its
   first surface knot matches within 0.001 mm. S105 whole-plate RMSE is
   0.10553, block 0.13244 and surface 0.07909, with surface ink 0.599% versus
   0.489%. An explicit per-cell contour-width mode now lowers S105 whole-plate
   RMSE from 0.10555 to 0.09792; its block crop is 0.12095 and surface crop
   0.07598. Surface ink moves from 0.599% to 0.510% against 0.489% source.
   Applying this mode to M9 instead raises RMSE from 0.22411 to 0.24644 and
   ink coverage from 4.224% to 4.432%, so M9 retains uniform connected strokes
   while its contour traversal and brush phase are investigated. Source-scaled
   16.16 thin-brush threshold rounding moves the current S105 column-stream
   comparison from 0.09852 to 0.09837; block/surface crops improve from
   0.12161/0.07655 to 0.12142/0.07644. cLine traversal interpolation, dash
   recursion and source random-call ordering remain open.
3. **Reconcile `flatSurface` and the S103 fill families.** The port now uses
   upstream stroke/row scales, the lightness envelope, three-track stipples,
   and the source's four-row glass dash cycle. At 600 ppi S103 whole-plate
   RMSE is 0.21682 (baseline 0.23772), with opaque, gradient and glass
   coverages all close to source. S104's fixture now maps its source +30° hatch
   to −30° in Typst page coordinates because `P()` flips the vertical axis.
   Reversing the opt-in MetaPost stream traversal also matches the source's
   y-up row order. The brush now also uses MetaPost's randomized 3–5 segment
   `pathSubdivide` count per hatch line. These changes lower S104 whole-plate
   RMSE to 0.20725 and hatch crop RMSE to 0.07650; hatch ink coverage is
   14.37% versus 14.07% in the source, while stipple coverage remains close
   (7.14% versus 7.08%). Source row-level tracing found 1516 calls across 142
   drawable rows versus 1322 before the threshold fix. Rounding the width
   level ratio as a dimensionless 16.16 scalar raises Typst to 1540 calls,
   with exact per-row counts on 108 rows; hatch crop RMSE falls further to
   0.07530 and whole-plate RMSE to 0.20703. An earlier prototype incorrectly
   quantized this ratio as a millimetre length and regressed; it was reverted.
   Prior S104 width and row-phase scans used the wrong hatch orientation and
   are superseded. Remaining hatch differences are concentrated in brush
   stroke shape and random details.
4. **Split M11 into faithful globe and knot renderers.** The public `globe`
   offers latitude hatching and `strand-knot` draws longitudinal tube segments
   with per-crossing layers and either gaps or local silhouette masks. Mapping the upstream strand parameter to
   the same tube radius and removing the M11 fixture's unsupported extra gap
   lowers whole-plate RMSE to 0.12630 and knot RMSE to 0.14316; knot ink
   coverage is 2.266% (source 2.606%). Tube-style gaps now account for the
   crossing angle, reducing knot crop RMSE from 0.14362. Mask mode now splits
   each strand midway between adjacent crossings, sorts the resulting tube
   segments by their source layer values, then erases prior marks with the
   higher segment's silhouette before drawing its hatch. This lowers M11 knot
   crop RMSE from 0.14280 to 0.14230; ink is 2.242% versus 2.606% source.
   Boundaries still use sampled-polyline arc length rather than source curve
   time, and tube masks use a white stroke approximation. The latitude mode
   still approximates the source's two separately masked shading layers and
   random width law.
   The coast brush now follows the source projected-radius pen-width law;
   `coast-step: 0` also preserves the source's projected control-point chords;
   together these give globe crop RMSE 0.19545. Globe ink coverage is 25.12%
   versus 25.94% in the source, so dash phase and brush recursion remain
   approximate. Keep eye and refraction as independent component gates.
5. **Tune the mechanical details from local crops.** S106 now maps the
   source's standing weight from its base upward and uses the source-derived
   body radii; its whole-plate RMSE falls from 0.10910 to 0.07788, standing
   crop from 0.12803 to 0.09949, and hanging crop from 0.11711 to 0.07319.
   Hanging coverage remains high because its auricle and hatch profile are
   still simplified.
   M10 uses the source-derived hanging-weight radius and profile; its whole-
   plate RMSE falls from 0.08506 to 0.07670. M8 uses the source
   2.5 mm hatched beam band, 3× minimum source rope width and thinpen pulley
   support line. Removing the duplicated rim stroke lowered whole-plate RMSE
   from 0.12971 to 0.11833 and ink coverage from 2.333% to 2.116% (source
   1.734%); source-mapped A/B/C labels and removal of the extra l/m labels
   account for the latest improvement. Pulley clipping remains approximate. S107's
   pulley-wheel crop RMSE is 0.09105 with near-equal ink coverage; the source-
   style wheel crop RMSE fell from 0.25567 to 0.12807, with coverage within
   about 15% of source. M10 and S102 are closer and can remain lower priority unless
   visual review finds a specific defect.

At each step, keep a same-input nominal comparison, review the difference
image, and record geometry, dark coverage and ink coverage together. Keep any
visual-only parameter calibration in its own mode. The Typst-only pixel
regression suite remains a change detector; source parity is measured by
`compare.sh` and reviewed source/Typst/difference images.
