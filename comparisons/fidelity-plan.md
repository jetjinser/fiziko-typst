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
| M8 pulley composites | 0.12579 | 1.734% → 2.212% | The pulley uses its wheel's existing thin outer rim and a thinpen support outline; the redundant 0.6 pt silhouette stroke is removed. Whole-plate RMSE improves; left/right crop RMSE is 0.13914/0.11258, with both crops still over-inked. Wheel/support clipping and label placement still differ. |
| M9 wood panels | 0.22730 | 4.203% → 4.504% | A continuous MetaPost stream advances across panels; the field uses one source-sized random vertical offset per 1 mm column. Knot candidates now use the source's rejection-until-ten rule and minimum spacing. Accepted-knot brush RNG consumption and contour-level random draws remain approximate. |
| M10 mechanics and optics | 0.08506 | 0.672% → 0.823% | Spring/weight crop RMSE 0.11766; lens/rays 0.06302. |
| M11 globe, eye, knot, refraction | 0.12972 | 4.917% → 4.885% | Latest 600 ppi candidate: globe uses separate land/ocean masks, RMSE 0.20950, ink coverage 25.940% → 25.819% (the earlier unmasked candidate scored 0.18935). Knot tube radius now matches the source parameter directly, and hidden-strand clearance is radius plus optional margin; knot RMSE is 0.14362 with ink coverage 2.302% (source 2.606%). Curve-time detection and tube masks remain approximate. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.32805 | 10.630% → 9.748% | Rows now use the source's rounded count and fitted spacing; hatch replays the MetaPost dash RNG stream but remains under-dense (14.066% → 12.273%, RMSE 0.36479). Stipple ink is 7.079% → 7.138%. Whole-plate RMSE remains above the earlier 0.29890 candidate. |
| S105 wood block and surface | 0.10449 | 0.741% → 0.828% | Latest 600 ppi candidate: wooden-surface RMSE 0.07922, ink coverage 0.489% → 0.604% (previously 0.13138 and 0.489% → 1.754%). Block is at RMSE 0.13048 and near-source coverage (1.077% → 1.135%). |
| S106 weights | 0.10910 | 1.162% → 0.805% | Standing weight crop 1.692% → 0.853%; hanging weight 1.208% → 0.986%. |
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
   library default remains keyed. Continue by threading the stream through a
   brush, one stipple family and wood, checking their source call order before
   considering broader defaults.
2. **Bring the wood field closer to `woodBlock`.** The first port now uses the
   source's knot-warped scalar field, 1 mm sample grid, and rotated panel axes.
   At 600 ppi M9 whole-plate RMSE is now 0.22848; reducing source-field
   contour width from 0.07 pt to 0.05 pt improved every panel (crop RMSE
   0.223–0.234) and moved ink coverage from 5.57% to 4.64% (source 4.20%).
   S105 block RMSE fell from
   0.14057 to 0.13129; coverage shifted from 1.14% to 1.17% (source 1.08%).
   The S105 wooden surface now also uses the knot-warped field: its 600 ppi
   crop RMSE fell from 0.13138 to 0.07958, and coverage moved from 1.754% to
   0.611% (source 0.489%). Knot placement is reproducible and panels share
   one stream, but accepted-knot brush calls do not yet advance the exact
   upstream global stream; contour pen widths and knot loops remain
   approximate. Dynamic knot
   rejection now follows the source's ten-rejection stopping rule; at 600 ppi
   this moves M9 whole-plate RMSE from 0.22800 to 0.22730 and ink coverage
   from 4.550% to 4.504%. Replaying accepted-knot brush RNG consumption with
   the current approximate brush renderer was tested and regressed M9 RMSE to
   0.22780, so that simulation was removed. Exact brush subdivision and source
   RNG call counts, contour-level random draws, and brush-shaped knot contours
   remain open. S105 remains stable at whole-plate RMSE 0.10450, block 0.13047
   and surface 0.07925 (surface ink 0.603% vs 0.489% source).
3. **Reconcile `flatSurface` and the S103 fill families.** The port now uses
   upstream stroke/row scales, the lightness envelope, three-track stipples,
   and the source's four-row glass dash cycle. At 600 ppi S103 whole-plate
   RMSE is 0.21682 (baseline 0.23772), with opaque, gradient and glass
   coverages all close to source. S104 stipple ink coverage matches (7.12% vs
   7.08%), but hatch remains under-dense (12.28% vs 14.07%) and S104
   whole-plate RMSE is 0.32819 (baseline 0.29890). A 2.3× hatch-width trial
   moved crop coverage to 13.90% (source 14.07%) but raised hatch RMSE from
   0.36477 to 0.37022; removing the lightness lower clamp overfilled it to
   20.19% and raised RMSE to 0.39024. Neither trial is retained. Quarter- and
   half-spacing row-phase trials barely moved hatch RMSE (0.36477 → 0.36473 /
   0.36475) and left coverage unchanged. The remaining difference likely needs
   closer source brush subdivision and shared random-stream order, rather than
   further phase or width tuning.
4. **Split M11 into faithful globe and knot renderers.** The public `globe`
   offers latitude hatching and `strand-knot` draws longitudinal tube segments
   with per-crossing layers and gaps. Mapping the upstream strand parameter to
   the same tube radius and removing the M11 fixture's unsupported extra gap
   lowers whole-plate RMSE to 0.12972 and knot RMSE to 0.14362; knot ink
   coverage is 2.302% (source 2.606%). The latitude mode still approximates the source's
   two separately masked shading layers and random width law; curve-time
   crossing detection, source tube masks and strand interpolation also differ.
   Keep eye and refraction as independent component gates.
5. **Tune the mechanical details from local crops.** M8 uses the source
   2.5 mm hatched beam band, 3× minimum source rope width and thinpen pulley
   support line. Removing the duplicated rim stroke lowered whole-plate RMSE
   from 0.12971 to 0.12579 and ink coverage from 2.333% to 2.212% (source
   1.734%). Pulley clipping and labels remain approximate. S107's
   pulley-wheel crop RMSE is 0.09105 with near-equal ink coverage; the source-
   style wheel crop RMSE fell from 0.25567 to 0.12807, with coverage within
   about 15% of source. M10 and S102 are closer and can remain lower priority unless
   visual review finds a specific defect.

At each step, keep a same-input nominal comparison, review the difference
image, and record geometry, dark coverage and ink coverage together. Keep any
visual-only parameter calibration in its own mode. The Typst-only pixel
regression suite remains a change detector; source parity is measured by
`compare.sh` and reviewed source/Typst/difference images.
