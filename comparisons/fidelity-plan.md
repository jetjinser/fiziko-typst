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
| M9 wood panels | 0.22456 | 4.203% → 4.272% | Landscape panels now use the source's internal axis swap. The first panel's first accepted knot matches its traced source coordinate; each accepted knot advances the 28 brush random draws observed in MetaPost. Contour-brush RNG calls still shift later panel streams. |
| M10 mechanics and optics | 0.07670 | 0.645% → 0.821% | Source hanging-weight radius, 1/4 neck, shoulder expansion and body taper reduce spring/weight crop RMSE to 0.10150; lens/rays remain 0.06302. Auricle and hatch remain approximate. |
| M11 globe, eye, knot, refraction | 0.12639 | 4.917% → 4.780% | Latest 600 ppi candidate: globe uses separate land/ocean masks and the source coast pen law, RMSE 0.19552 with ink coverage 25.940% → 25.120% (prior masked candidate 0.20950; unmasked baseline 0.18935). Knot tube radius matches the source parameter directly and hidden-strand clearance is radius plus optional margin; knot RMSE is 0.14362 with ink coverage 2.302% (source 2.606%). Latitude-layer width laws, coast RNG phase, curve-time crossing detection and tube masks remain approximate. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.21054 | 10.630% → 10.287% | Mapping the source +30° hatch through the fixture's vertical-axis flip gives Typst angle −30°. Reversing the MetaPost RNG draw order to match its y-up scan gives hatch crop RMSE 0.09247 and ink coverage 14.066% → 13.333%. Stipple coverage is 7.079% → 7.138%. Hatch brush shape remains approximate. |
| S105 wood block and surface | 0.10635 | 0.741% → 0.882% | Landscape-axis mapping follows the source's `woodBlock` transform. Current 600 ppi block RMSE is 0.13330; surface RMSE is 0.07996 with ink 0.489% → 0.623%. Source contour-brush rendering and random-stream continuity from the block into the surface remain open. |
| S106 weights | 0.07788 | 1.091% → 1.120% | Standing crop RMSE is 0.09949 with ink 1.594% → 1.474%. The source-derived hanging profile reduces crop RMSE from 0.11711 to 0.07319; ink is 1.131% → 1.296%. Source auricle and hatch details remain open. |
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
2. **Bring the wood field closer to `woodBlock`.** The field uses the source's
   knot-warped scalar field, 1 mm sample grid, per-column offset, and
   per-contour level jitter. Landscape blocks now reproduce the source's
   internal axis swap, and a trace of the pinned source shows that each
   accepted knot consumes 28 random draws in its nested brush rings. The first
   M9 panel's first accepted knot now matches source coordinates to under
   0.1 mm; M9 whole-plate RMSE improves from 0.22688 to 0.22456, with ink
   coverage 4.272% versus 4.203%. Contour-brush random calls still leave later
   panel streams approximate. The S105 block/surface layout also gets the
   source landscape transform; its current whole-plate RMSE is 0.10635,
   block 0.13330 and surface 0.07996, with surface ink 0.623% versus 0.489%.
   Its source contour-brush rendering and stream continuity from plank to
   surface still need work.
3. **Reconcile `flatSurface` and the S103 fill families.** The port now uses
   upstream stroke/row scales, the lightness envelope, three-track stipples,
   and the source's four-row glass dash cycle. At 600 ppi S103 whole-plate
   RMSE is 0.21682 (baseline 0.23772), with opaque, gradient and glass
   coverages all close to source. S104's fixture now maps its source +30° hatch
   to −30° in Typst page coordinates because `P()` flips the vertical axis.
   Reversing the opt-in MetaPost stream traversal also matches the source's
   y-up row order. These changes lower S104 whole-plate RMSE from 0.32805 to
   0.21054 and hatch crop RMSE from 0.36479 to 0.09247; hatch ink coverage is
   13.33% versus 14.07% in the source, while stipple coverage remains close
   (7.14% versus 7.08%). Prior S104 width and row-phase scans used the wrong
   hatch orientation and are superseded. Remaining hatch differences are
   concentrated in brush stroke shape and random details.
4. **Split M11 into faithful globe and knot renderers.** The public `globe`
   offers latitude hatching and `strand-knot` draws longitudinal tube segments
   with per-crossing layers and gaps. Mapping the upstream strand parameter to
   the same tube radius and removing the M11 fixture's unsupported extra gap
   lowers whole-plate RMSE to 0.12639 and knot RMSE to 0.14362; knot ink
   coverage is 2.302% (source 2.606%). The latitude mode still approximates the source's
   two separately masked shading layers and random width law; curve-time
   crossing detection, source tube masks and strand interpolation also differ.
   The coast brush now follows the source projected-radius pen-width law;
   this lowers globe crop RMSE from 0.20950 to 0.19552. Globe ink coverage is
   25.12% versus 25.94% in the source, so dash phase and brush recursion remain
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
