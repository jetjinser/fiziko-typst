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
| M9 wood panels | 0.21329 | 4.203% → 3.778% | The comparison reproduces its source driver's 1 mm `woodBlockRes`, source-ordered fractional contour levels, and source-space knot field. A 72-point source/Typst grid probe differs by 0.00029 normalized units on average (0.00151 max); the first traced contour pairs within 0.11 mm mean vertex distance. Enabling the measured per-cell `cLine` width law lowers 600 ppi RMSE from 0.21526 to 0.21328. A shared brush endpoint guard now follows source path-time units; this improves recursion semantics but moves the raster score slightly to 0.21329. Ink remains low (3.778% vs 4.203% source), and exact recursive width interpolation/dash calls remain open. |
| M10 mechanics and optics | 0.07533 | 0.645% → 0.810% | Source hanging-weight radius, 1/4 neck, shoulder expansion, 2 mm body offset and a 2*shadingDensity auricle capsule reduce spring/weight crop RMSE to 0.09878 (previous 0.09909); lens/rays remain 0.06302. Auricle interior shading remains approximate. |
| M11 globe, eye, knot, refraction | 0.11267 | 4.917% → 5.070% | Focused 600 ppi rerun after source-ordered boundary lanes and shared knot RNG: globe crop RMSE 0.18875; knot crop RMSE 0.05895 (lane-only candidate 0.05896), with knot ink 2.606% → 2.843%. The globe projection and source-ordered horizon arcs remain close. The knot fixture uses 385 source-curve points per strand; mask mode splits at crossing-interval midpoints, erases prior ink with higher tube silhouettes, and redraws hatch. Three crossing times match source times 6, 12, and 18. A new path-paired lane trace finds all six source/Typst tube intervals have exact matching endpoints, but per-interval random calls differ (source draw order: 14/58/54/42/38/18; paired Typst: 10/38/40/52/50/14). This rules out a missing interval as the cause of the 20-call deficit; lane-width profiles and their shading geometry remain under investigation. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.20703 | 10.630% → 10.810% | Mapping source +30° through the fixture's vertical flip gives Typst −30°; reversed row traversal and source-randomized 3–5 path subdivision lower hatch crop RMSE to 0.07650. Unit-aware 16.16 width-level rounding then lowers it to 0.07530, with hatch ink 14.066% → 14.363%. Stipple coverage remains 7.079% → 7.138%. The thin-recursion endpoint guard now uses source path-time units: paired outer decisions move from 942 to 1270 (source 1340), thin decisions from 1577 to 1739 (source 1696), with no raster change. Brush-call totals remain 1540 vs 1516 source. |
| S105 wood block and surface | 0.10314 | 0.741% → 0.712% | The source-derived field now uses the 1/3 mm `woodBlockRes`, fractional source contour levels and source-space landscape knot transform. After the shared source path-time endpoint guard, the 600 ppi block RMSE is 0.12855 (ink 1.077% → 0.917%); surface RMSE remains 0.07851 (ink 0.489% → 0.563%). This is a small additional block-raster regression while following the source recursion guard; it remains worse than the prior tuned 0.09792. Width interpolation, dash calls and surface-specific tuning remain open. |
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
   Sampling M4's actual MetaPost spline at 1/16 path-time intervals (641 points)
   replaces the ideal-circle approximation and lowers its RMSE from 0.07025 to
   0.06019 (the 1/8 result was 0.06050). A 1/32 sample was killed before
   producing metrics, so retain 1/16 as the best completed source-path sample;
   extraction remains reproducible from the pinned driver.
   The source includes two boundary lanes in addition to the interior tube
   lanes. A source-derived section-boundary implementation is now retained;
   its M11 tube mask and hatch ordering lower knot RMSE, although M4/M6 show
   coverage tradeoffs. For M11, source tube hatches begin at global RNG offset
   4639. Precomputing the six visible segments in source layer order with a
   shared stream lowers the 600 ppi knot crop RMSE from 0.058960 to 0.058950
   and whole M11 RMSE from 0.112673 to 0.112672. This is a small raster gain;
   it is retained as the more faithful source call-order implementation.
   Endpoint-paired source/Typst traces confirm all six tube intervals are
   present with matching endpoints. Their per-interval random calls are
   source 14/58/54/42/38/18 versus Typst 10/38/40/52/50/14 in source order,
   exposing large compensating lane-level differences rather than an omitted
   interval. The first checked source/Typst inner-lane width maxima also differ
   (source 0.04524 mm, Typst 0.03634 mm on source call 2, lane 6), pointing to
   the local shading geometry as the next comparison. Knot ink coverage remains
   high (2.843% vs 2.606%).
   A diagnostic that reduced dense Typst widths to quarter-path-time knots and
   interpolated them by lane arc left the 204 total calls unchanged and raised
   the six-segment absolute call-count error from 64 to 68; it was discarded.
   The remaining gap requires matching the source's offset-boundary paths.
   Exact recursive subdivision, variable-radius boundary behavior, brush
   stipples and further wood call-order matching remain open.
2. **Bring the wood field closer to `woodBlock`.** The field now uses source
   grid coordinates, `woodBlockRes`-scaled knot radii, the source angle
   convention, and one offset draw per actual source column. M9's comparison
   uses the driver's explicit 1 mm resolution; S105 uses the source default
   1/3 mm. A 72-sample M9 lattice trace matches within 0.00029 normalized
   units on average. Source contour levels preserve the fractional phase of
   the sampled maximum and subtract the source's positive jitter. This lowers
   M9 whole-plate RMSE to 0.21563 with uniform contour strokes, then 0.21328
   with the per-cell width law; coverage is still 3.778% versus 4.203% source.
   The source field equations improve grid agreement but move S105 from its
   tuned 0.09792 to 0.10304, so retain this tradeoff visibly while resolving
   cLine traversal and brush calls. A
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
   An internal arc-length width interpolation probe leaves every tested call
   count unchanged, confirming that the polygon geometry/knot placement must be
   corrected before the remaining ring-2 recursion difference can be addressed.
   The pinned cubic `fullcircle` is now sampled at 1/32 path-time intervals;
   the existing cubic sampler matches it within `3.1e-5` normalized units and
   reproduces the source ring counts exactly. Using those rings in the current
   Typst band renderer worsens M9 RMSE from 0.22442 to 0.22843 and ink coverage
   from 4.273% to 4.468% (source 4.203%), so that production candidate was
   reverted. Brush offset/leaf geometry remains the next wood-knot gap.
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
   `pathSubdivide` count per hatch line. Reproducing its cumulative 16.16 path
   times adds the source's short terminal segment on requested 3- and 5-way
   subdivisions. S104 whole-plate RMSE falls from 0.20725 to 0.20703 and hatch
   crop RMSE from 0.07650 to 0.07529; hatch ink coverage is 14.359% versus
   14.066% in the source, while stipple coverage remains close (7.14% versus
   7.08%). Source row-level tracing found 1516 calls across 142
   drawable rows versus 1322 before the threshold fix. Rounding the width
   level ratio as a dimensionless 16.16 scalar raises Typst to 1540 calls,
   with exact per-row counts on 108 rows; hatch crop RMSE falls further to
   0.07530 and whole-plate RMSE to 0.20703. An earlier prototype incorrectly
   quantized this ratio as a millimetre length and regressed; it was reverted.
   Prior S104 width and row-phase scans used the wrong hatch orientation and
   are superseded. A follow-up found 34 mismatched row counts, concentrated in
   the variable-width interior and reaching ±20 calls per row. Rounding width
   samples to 16.16 leaves those calls unchanged and slightly regresses hatch
   RMSE (0.075286 to 0.075353), so it was reverted. A fresh source trace shows
   that the S104 fixture's sampled width knots already match Typst after unit
   conversion. Quantizing recursive cut parameters to the source 16.16 path
   grid raises Typst outer recursion nodes from 780 to 942 (source: 1340),
   while thin nodes remain 1577 (source: 1696); one traced 31.180 mm row now
   matches the source's 39 outer and 9 thin nodes. Hatch crop RMSE is
   effectively unchanged at 0.075285 (previously 0.075286), so this is a
   recursion-fidelity improvement, not a material raster improvement. Other
   rows still differ around narrow residual crossings; brush shape and random
   details remain open. A new trace found symmetric crossing ties where
   floating-point arc accumulation selected the opposite side from source
   `cutPathTime`. A tiny source-mode tie tolerance moves a representative cut
   to within 0.001 mm of the source-selected intersection. With no width
   quantization, hatch crop RMSE improves to 0.07528521 and whole-plate RMSE
   to 0.20702865; aggregate recursion counts stay 942/1577. Reapplying
   16.16 rounding to recursive cut widths lowers outer nodes to 814 and
   worsens hatch RMSE to 0.07529141, so that trial was reverted.
   A separate unit audit found that `thinBrushGenerate` guards endpoints in
   path-time units, while Typst had compared the 0.01 margin to arc length.
   Applying the margin to the quantized path parameter moves aggregate
   decisions to 1270 outer and 1739 thin nodes (source 1340/1696); 80/142
   endpoint-paired rows now match both node counts exactly. S104's 600 ppi
   hatch and whole-plate RMSE are unchanged at 0.07528521/0.20702865, and M4/M6
   pixel hashes match their prior retained tube candidates. The first row with
   a random-call mismatch requests the same three subdivisions on both sides
   and has cut positions within 0.001 mm, but consumes 11 source calls versus
   7 in Typst. A terminal-leaf trace identifies the concrete split: source has
   19 thin recursion nodes and 5 dashed leaves on that row, while Typst has 17
   nodes and 3 dash-eligible leaves. Unique source leaf IDs now pair five
   source dashes against three Typst dashes. The first tree divergence is a
   shared depth-4 path: MetaPost cuts it at x=39.539 mm, while Typst cuts it at
   x=44.895 mm. The selected width base, step and level agree after unit
   conversion: source values are 0.06642/0.00830/0.15773 pt; Typst's
   corresponding values convert from 0.023432/0.002928/0.055644 mm to the
   same values. The residual is therefore in the sampled crossing geometry or
   midpoint selection, not the width thresholds. A diagnostic-only arc-length
   interpolation trial left the row's 17-node tree unchanged. A flat-interval
   crossing candidate increased total Typst thin nodes from 1739 to 3259
   (source: 1696), so it was reverted. Keep the production model until the
   source template knots and corresponding Typst sample intervals are paired.
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
   The current sampled paths reproduce source crossing times 6, 12, and 18
   exactly; source curve intersection arithmetic remains unported. An exact
   `tubeOutline` source-mask oracle changes current knot RMSE only from
   0.05904362 to 0.05903513, so mask offset geometry is a small part of the
   remaining raster gap; hatch placement and coverage remain larger. A new
   source trace pairs the six offset boundaries with the corresponding Typst
   lanes: mean point error is 0.0005–0.0012 mm, with mean tangent error
   0.04–0.10 degrees. This makes boundary geometry an unlikely source of the
   remaining 20-call deficit. Source normal/lightness samples are now recorded
   alongside shadow hits; the Typst diagnostic retains each lane's radial
   coordinate, sample points, widths and lightness. For source call 2/lane 6,
   `asin(u)` matches the source cross-section angle within 8.8e-6 rad; the
   center tangent differs by 0.0051 rad on average, and both radius slopes are
   zero. The source's even `k=6` has no parity width factor: its sampled width
   averages 0.01996 mm (max 0.04525 mm), versus Typst 0.04315 mm (max
   0.05493 mm). A radial-y sign trial matches pointwise source lightness and
   widths and moves M11's six-segment absolute call-count error from 64 to 20
   (source calls 14/58/54/42/38/18; candidate 14/52/50/40/38/10), while the
   total remains 204 versus 224. It nevertheless worsens 600 ppi RMSE for M11
   knot (0.05895→0.07697), M4 (0.07109→0.12625) and M6 (0.08919→0.11594), so
   the render change was reverted. On paired k=6, source has 19 dash leaves,
   current Typst 5, and candidate Typst 17. Its quantized dash widths match
   within 0.00002 mm; two source pairs are merged across 0.064 and 0.054 mm
   gaps. At both troughs, the source normal trace gives 0.026209 mm width
   versus candidate 0.026759 mm, despite point error below 0.00011 mm; the
   centerline angle differs by 0.02009 rad. The source instrument now emits
   the 36 cubic segments of `currentTubePath` and lane `currentPath`; use their
   controls to recover the exact tangent at the narrow-width samples, then
   reproduce the two dash-phase restarts. The latitude mode
   still approximates the source's two separately masked shading layers and
   random width law.
   A follow-up tested a three-point one-sided tangent on the sampled center
   path together with the radial-y sign change. The diagnostic initially
   reported 17 dash leaves, but its light vector was not normalized like the
   production renderer; after correcting the diagnostic, production and
   helper widths agree to 1.4e-17 mm and both produce 16 leaves. The combined
   render scores 0.11447 whole-plate RMSE and 0.07677 knot-crop RMSE, worse
   than the retained 0.11267/0.05895 baseline. The production change was
   reverted. This does not isolate the tangent estimator from the radial-y
   sign change; do not treat the apparent 17-leaf match as evidence for
   either change.
   The coast brush follows the source projected-radius pen-width law, and the
   projection and geographic mask inverse now match the source longitude
   convention. Globe crop RMSE falls from 0.18877 to 0.18875 and ink coverage
   is 26.443% versus 25.940% source. Typst now merges the seam runs, applies
   the source's five-step horizon crossing and arc-conflict rules, and brushes
   six closed outlines. Traced arc times agree with the pinned source within
   0.001 fullcircle units. Dash phase and recursive brush calls remain
   approximate. A fixed stream offset tested with the prior projection was
   reverted; re-evaluate it against the closed contours.
   Keep eye and refraction as independent component gates.
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
