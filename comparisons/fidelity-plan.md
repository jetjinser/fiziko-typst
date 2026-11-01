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
| M8 pulley composites | 0.13182 | 1.734% → 2.229% | After matching the 2.5 mm hatched beam band and 3× minimum source rope width, left crop RMSE is 0.14480 and right 0.11917; both remain mildly over-inked. |
| M9 wood panels | 0.29579 | 4.349% → 7.570% | All four panel crops score about 0.291–0.300 RMSE; the port's smooth field does not reproduce the source's irregular knot-driven grain. |
| M10 mechanics and optics | 0.08506 | 0.672% → 0.823% | Spring/weight crop RMSE 0.11766; lens/rays 0.06302. |
| M11 globe, eye, knot, refraction | 0.13134 | 4.917% → 5.036% | Latest 600 ppi candidate: globe RMSE 0.18935, ink coverage 25.940% → 27.538%; knot RMSE 0.17410, 2.606% → 1.669%. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.06951 | 1.818% → 1.884% | Tube crop coverage is 0.621% → 0.613%; sphere crop is 5.700% → 5.955%. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.32819 | 10.630% → 9.745% | At 600 ppi stipple coverage now matches (7.079% → 7.121%, RMSE 0.28549). Hatch is still under-dense (14.066% → 12.284%, RMSE 0.36477); overall RMSE regressed from 0.29890 despite better density balance. |
| S105 wood block and surface | 0.10509 | 0.741% → 0.846% | Latest 600 ppi candidate: wooden-surface RMSE 0.07958, ink coverage 0.489% → 0.611% (previously 0.13138 and 0.489% → 1.754%). Block remains at RMSE 0.13129 and near-source coverage (1.077% → 1.166%). |
| S106 weights | 0.10910 | 1.162% → 0.805% | Standing weight crop 1.692% → 0.853%; hanging weight 1.208% → 0.986%. |
| S107 wheels and centroid | 0.14064 | 3.159% → 3.441% | New source-style wheel (600 ppi): RMSE fell from 0.25567 to 0.12807 and coverage is 6.034% vs 7.100%. Pulley wheel remains over-inked (RMSE 0.23299; 3.833% → 5.689%); centroid crop RMSE 0.05441. |
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
   The S105 wooden surface now also uses the knot-warped field: its 600 ppi
   crop RMSE fell from 0.13138 to 0.07958, and coverage moved from 1.754% to
   0.611% (source 0.489%). Knot placement is reproducible but still uses
   per-panel seed offsets rather than the exact upstream global call stream;
   contour pen widths and knot loops remain approximate. The shared RNG cursor
   and brush-shaped knot contours are the next wood-specific improvements.
3. **Reconcile `flatSurface` and the S103 fill families.** The port now uses
   upstream stroke/row scales, the lightness envelope, three-track stipples,
   and the source's four-row glass dash cycle. At 600 ppi S103 whole-plate
   RMSE is 0.21682 (baseline 0.23772), with opaque, gradient and glass
   coverages all close to source. S104 stipple ink coverage matches (7.12% vs
   7.08%), but hatch remains under-dense (12.28% vs 14.07%) and S104
   whole-plate RMSE is 0.32819 (baseline 0.29890). Further work should inspect
   row placement and edge clipping in S104; width-only tuning matched coverage
   but raised crop RMSE, so keep source-derived width parameters.
4. **Split M11 into faithful globe and knot renderers.** The public `globe`
   now offers a latitude-hatching mode, and `strand-knot` can draw longitudinal
   tube segments with over/under gaps. The M11 600 ppi trial reduced whole-plate
   RMSE from 0.24449 to 0.13134; globe RMSE fell from 0.49895 to 0.18935 and
   knot from 0.30447 to 0.17410. Globe ink coverage is close, while knot is
   under-inked by about 36%. The latitude mode still approximates the source's
   two separately masked shading layers and random width law; crossing gaps
   and strand path interpolation also differ. Tune those locally, keeping eye
   and refraction as independent component gates.
5. **Tune the mechanical details from local crops.** M8 now uses the source
   2.5 mm hatched beam band and 3× minimum source rope width; whole-plate RMSE
   fell from 0.16877 to 0.13182 and ink coverage moved from 3.23% to 2.23%
   (source 1.73%). Pulley geometry and labels remain approximate. S107's
   source-style wheel crop RMSE fell from 0.25567 to 0.12807, with coverage
   within about 15% of source; the pulley wheel still differs (RMSE 0.23299 and
   excess ink). M10 and S102 are closer and can remain lower priority unless
   visual review finds a specific defect.

At each step, keep a same-input nominal comparison, review the difference
image, and record geometry, dark coverage and ink coverage together. Keep any
visual-only parameter calibration in its own mode. The Typst-only pixel
regression suite remains a change detector; source parity is measured by
`compare.sh` and reviewed source/Typst/difference images.
