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
| M9 wood panels | 0.21156 | 4.203% → 3.712% | The comparison reproduces its source driver's 1 mm `woodBlockRes`, source-ordered fractional contour levels, and source-space knot field. The source/Typst contour pairing has an exact reversed 19-cell sequence; per-cell ranges differ by 1.54e-5 mean and 4.92e-5 max. Rounding source-scaled field corners, interpolated ranges and dimensional brush widths to 16.16, then using the reversed source-path-time width profile, lowers same-grid RMSE to 0.211560. Ink remains below source; full-path brushing regressed every panel crop and was reverted. |
| M10 mechanics and optics | 0.07533 | 0.645% → 0.810% | Source hanging-weight radius, 1/4 neck, shoulder expansion, 2 mm body offset and a 2*shadingDensity auricle capsule reduce spring/weight crop RMSE to 0.09878 (previous 0.09909); lens/rays remain 0.06302. Auricle interior shading remains approximate. |
| M11 globe, eye, knot, refraction | 0.11295 | 4.917% → 5.056% | The source-equation coast normal and corrected `atan2` argument order move focused 600 ppi whole-plate RMSE from 0.11266 to 0.11295; globe crop RMSE is 0.18990 (previously 0.18875), while globe ink coverage moves closer from 26.443% to 26.353% against 25.940% source. For mass 4, the root recursive cut now splits 14.296/13.938 mm, matching source 14.292/13.925 mm. The fitted knot center cubic controls from 1/16 source samples match traced MetaPost controls within 0.000049 mm, with tangent error at most 0.000156 rad. Mask mode splits at crossing-interval midpoints, erases prior ink with higher tube silhouettes, and redraws hatch. Three crossing times match source times 6, 12, and 18. Knot crop RMSE is 0.05882, with knot ink 2.606% → 2.843%. Coast brush calls are 52 versus source 27 across visible masses; the corrected source-rounded lane diagnostic counts 212 knot calls versus 224 source. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.04909 | 1.818% → 1.887% | Matching the source's two smooth cubic tube joins with Hobby resampling at `per: 64` lowers tube-crop RMSE `0.07861 → 0.01821`; dark coverage is 0.6195% vs 0.6208% source. Sphere crop stays at 0.09110 and now dominates the residual. A source eight-knot lightness-only sphere probe moves dark coverage closer but regresses sphere RMSE to 0.10564; it was reverted. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.20703 | 10.630% → 10.810% | Mapping source +30° through the fixture's vertical flip gives Typst −30°; reversed row traversal and source-randomized 3–5 path subdivision lower hatch crop RMSE to 0.07650. Unit-aware 16.16 width-level rounding then lowers it to 0.07530, with hatch ink 14.066% → 14.363%. Stipple coverage remains 7.079% → 7.138%. The thin-recursion endpoint guard now uses source path-time units: paired outer decisions move from 942 to 1270 (source 1340), thin decisions from 1577 to 1739 (source 1696), with no raster change. Brush-call totals remain 1540 vs 1516 source. |
| S105 wood block and surface | 0.10215 | 0.741% → 0.689% | The source-derived field uses the 1/3 mm `woodBlockRes`, fractional source contour levels and source-space landscape knot transform. The source-path-time width profile lowers same-grid RMSE to 0.102148; block/surface crops are 0.127927/0.076936. Full-plate ink remains below source (0.6891% vs 0.7405%), while surface ink is 0.5309% vs 0.4892%; brush recursion and dash calls remain open. |
| S106 weights | 0.07663 | 1.091% → 1.106% | Standing crop RMSE is 0.09949 with ink 1.594% → 1.474%. The source-derived hanging profile plus a 2 mm body offset and 2*shadingDensity auricle capsule reduces hanging crop RMSE to 0.06998; ink is 1.131% → 1.263%. Auricle interior shading and tube hatch remain approximate. |
| S107 wheels and centroid | 0.08667 | 3.159% → 2.976% | Both source-style ring renderers now match closely: pulley-wheel RMSE 0.09105 with 3.947% vs 3.833% coverage; wheel RMSE 0.12807 with 6.034% vs 7.100%. Centroid crop RMSE 0.05441. |
| S108 lenses and annotations | 0.10093 | 0.476% → 0.890% | Lens crop RMSE 0.12716; arrow/angle annotation crop 0.08729. |

These whole-plate RMSE values are useful for locating large residuals, not for
ranking unlike subjects as if the scores were a universal similarity scale.
M11's globe crop, for example, combines a large shaded region with coastline
strokes, while M10 contains mostly whitespace.

## Confirmed actionable gaps

These are follow-ups with a pinned-source trace or a concrete source/Typst
divergence. “Confirmed” means the behavior to reproduce is evidenced by the
source; it does not promise that every implementation attempt improves raster
RMSE. Keep each change only when source-level agreement improves and the
affected source-parity crops do not materially regress.

- [x] **MetaPost fixed-point brush-width interpolation.** With
  `source-rounding: true`, `_ink-loops` separately rounds the scalar fraction,
  each dimensional width product, and their sum to source 16.16 precision.
  Same-checkout 600 ppi reports cover all 20 plates. M4 RMSE improves
  `0.06017598 → 0.05947335`; M11 improves `0.11295018 → 0.11289878`, with knot
  crop `0.05881920 → 0.05823034`; S105 improves `0.10214839 → 0.10213793`.
  M9 changes only `+0.00000057`, while S104 changes `+0.00001057` (hatch crop
  `+0.00005715`); the other 15 plates' regional metrics are identical. Keep
  the arithmetic correction with these small measured tradeoffs. It does not
  resolve the remaining M11 call-vector difference (`224` source, `226`
  Typst).

- [x] **M11 knot centerline tangent.** Reconstruct the source cubic from
  five equally spaced input samples over each four-interval source segment.
  The fitted controls match the traced MetaPost midpoint cubic within
  0.000049 mm; tangent error is at most 0.000156 rad (mean 0.000033 rad).
  The retained 600 ppi candidate lowers knot RMSE from 0.058950 to 0.058819
  and whole M11 RMSE from 0.112672 to 0.112661.
- [ ] **M11 knot dash-phase restarts.** The source-cubic geometry is now
  retained, but Typst still consumes 212 calls against 224 source calls across
  the six visible intervals. The rounded source-normal diagnostic now matches
  all 19 source dash leaves and 38 source calls on target lane k=6; projected
  leaf endpoints differ by 0.00364 mm mean and 0.01194 mm maximum arc length.
  It restores the phase restarts near 17.894 and 18.780 mm. The previous
  17-leaf result used `source-rounding: false` and was not representative of
  production tube rendering. The broader source-normal render candidate still
  regresses M11/M4/M6, so lane-level phase pairing is improved but no production
  shading change is retained. A regenerated source trace pairs call 2, lanes
  k=1–7 to Typst samples at the same positions (37 samples per lane, all within
  0.001 mm); current lightness MAE by lane is
  `0.32889/0.21929/0.10963/0/0.10963/0.21925/0.32890`, symmetric around k=4.
  This localizes the remaining discrepancy across the cross-section rather
  than to path sampling. Flipping the radial y component in the source-lighting
  formula lowers each of those seven lightness MAEs to `0.00001–0.00003`, but
  the M11 render regresses: whole-plate RMSE `0.112950 → 0.114784` and knot
  crop `0.058819 → 0.077068`. The production candidate was reverted; this
  points to recursive dash/call divergence after the width correction as the
  next issue to isolate. With source-rounded edges, the source-lighting
  candidate counts in source call order are `14/56/54/38/40/10` versus source
  `14/58/54/42/38/18`; the remaining mismatch is concentrated in calls 4–6.
  On those later intervals, source lane callback positions do not align with
  the uncut Typst lane samples, and source-normal L2 error remains 0.07–0.15.
  The source centerline cubics pair with Typst controls at 0.000010–0.000013 mm
  MAE (maximum below 0.000055 mm), and source lane controls fit the paired
  Typst sampled curves within 0.002 mm. The decisive difference is source
  `shadowCut`: at each shifted shadow-boundary intersection it trims 0.05
  path-time units on both sides, then joins the two subpaths with `..`. Calls
  1–3 keep their original path lengths (24/36); calls 4–6 change from
  36/36/24 to 39–41/39–40/28 units on the traced lanes. Although this looks
  like a gap, the join restores the removed cubic interval: on two call-4
  cuts, the joined cubic controls match the original de Casteljau subcurve
  within `3.8e-6` and `1.7e-5` mm. `shadowCut` therefore changes the path's
  knot topology and callback-time mapping while preserving its geometry to
  this precision. Typst currently lacks these inserted knots; its width and
  lightness callbacks follow the original sampling grid. Reproduce the
  sequential knot insertions and remap callbacks before brush recursion, then
  compare per-call RNG vectors and renders. The source intersection uses
  `light.xy * (lane-depth - 1.5 * occluder-width) * light.z`; traces record
  both depths, the light vector, shadow index, and evolving lane time.
  A first production candidate fitted lane cubics, inserted the traced
  `±0.05` knots at shifted-outline intersections, and sampled widths on the
  resulting path-time grid. Its call vector was `14/54/54/34/34/16` (206 total)
  against source `14/58/54/42/38/18`; the retained baseline is
  `14/56/54/38/40/10` (212 total). Absolute per-segment error rose from 16 to
  18. At 600 ppi, whole M11 RMSE regressed `0.11295018 → 0.11301771` and knot
  crop RMSE `0.05881920 → 0.05958444`, so the production candidate was
  reverted. The next probe must preserve the source q-path width interpolation
  and exact hit parameterization; geometric knot insertion alone is not
  sufficient. The source trace now establishes callback behavior for all nine
  expanded call-4–6 lanes: post-cut path lengths exceed the original length by
  3–5 units, while callback lightness and normal after the original endpoint
  match the endpoint sample at the trace's five-decimal precision.
  `offsetPathTemplate` therefore
  advances across the inserted lane knots while its lookups on the uncut
  centerline/width paths clamp at their endpoint. The new
  `diagnostics/analyze_m11_shadow_callbacks.py` verifies this from
  `M11PARAM`/`M11POSTPARAM` and `M11WIDTHINPUT`/`M11LIGHT`. Rebuild callback
  knots at integer post-cut times, including the repeated endpoint tail,
  before retrying brush recursion. A direct replay now feeds traced
  post-shadow cubics, callback widths, path times and source RNG offsets into
  the production `_ink-loops` routine. It matches source call totals on 15 of
  18 traced lane inputs; the only differences are call 4 lanes 2/6
  (`18/8` versus source `16/6`) and call 5 lane 2 (`12` versus source `14`).
  Calls 1–3 and 6 match across all three lanes. Increasing the geometric
  sampling density from one to four or sixteen samples per source cubic does
  not change those call totals, so the remaining discrepancy is localized to
  recursive branching or low-level arithmetic rather than broad path density.
  A source instrument now records callback widths as raw MetaPost bp 16.16
  values, encoded in two base-256 digits and converted to millimetres only
  after decoding. Across 1,895 samples, these differ from products of the
  five-decimal log values by at most `5.76e-6 mm` (mean `2.22e-6 mm`). Replay
  still matches 15/18 lane totals with the same three differences, so greater
  width precision has not resolved the branch mismatch. The regenerated trace
  preserves all 15,963 shared M11 marker lines exactly; additional width and
  recursive-path markers improve diagnosis without changing rendering.
  A focused `M11QPT` trace now captures the source width-template cubic
  controls for the divergent call-4/lane-2 recursion. `offsetPathTemplate`
  stores callback widths in 16.16 `--` cubics, and recursive `subpath` calls
  preserve their sliced controls. The replay currently reconstructs each
  branch with linear width interpolation; quantizing its cut time or rebuilding
  a fresh cubic per branch leaves the 15/18 call match unchanged. Model the
  original q cubic controls and carry their exact subpaths before changing
  production recursion. A diagnostic reconstruction from the original integer
  callback widths regressed to 14/18 because it ignored the q subpaths already
  sliced by the outer brush recursion; it was removed without a render trial.
  The source trace now stores raw 16.16 cut parameters. A dedicated analyzer
  verifies 18 parent/left-child and 18 parent/right-child two-dimensional q
  curves exactly using fixed-point de Casteljau subdivision with nearest-unit
  rounding. Reuse and recursively split those source q controls in the replay
  before changing production recursion. Typst now implements this 16.16
  subdivision primitive, and a paired replay matches all 18 left and 18 right
  child control arrays exactly after quantization. The primitive is not yet
  wired into `_ink-loops`, so no renderer change is claimed.
  An expanded source trace now covers the three divergent lanes: fixed-point
  subdivision verifies 19/9/14 parent-left and parent-right pairs for calls
  4/lane 2, 4/lane 6 and 5/lane 2, and the Typst primitive matches every
  control array. `brushGenerate` tracing also shows that MetaPost renumbers a
  partial cubic in a `subpath` as a full local path-time interval: call 4/lane
  2 cuts its 40-segment root at `22.33324`, then the 23-segment left child
  reports its next cut near `22.9997`. A diagnostic q-state port that preserved
  these remapped knots leaves call 4/lane 2 at 18 calls (source: 16), with 56
  thin nodes and 30/40 source endpoint pairs; the baseline has 34 thin nodes
  and 32/40 endpoint pairs. The production candidate was removed. The next
  attempt must pair recursive q-time remapping with the corresponding
  centerline subpath parameters before changing cut selection.
  Source recursive nodes now include their geometric endpoints and cut points.
  In call 4 lane 2, the source chooses width `0.03807` and splits near
  `(89.32121,15.79910)`; adjacent source pieces of `0.30544` and `0.31416` mm
  stay below the dash-length gate. Typst chooses `0.041`, cuts near
  `(89.615,15.686)`, and emits a `0.61732` mm dash, accounting for two extra
  random calls. The enclosing path endpoints differ by only a few micrometres,
  while the branch minimum width differs by `0.00002` mm and crosses a source
  width-step boundary. This is now localized to recursive width-template
  splitting; keep production unchanged until that source rule is reproduced
  and the render is rechecked.
  This replay is diagnostic only; no production rendering change is justified
  until the three divergent branch trees are paired and a render improves.
  The replay now samples callback widths linearly in source path time,
  matching `offsetPathTemplate`'s straight `--` segments between integer-time
  samples. This replaces the diagnostic's former arc-length interpolation;
  the same 15/18 call totals remain, so the three branch mismatches persist.
  A sweep from 1 through 32 geometry samples per source cubic leaves those
  calls unchanged. Rounding mapped `param-at` values to 16.16 also leaves the
  call vector unchanged and slightly regresses same-checkout M11 RMSE
  (`0.1128986841 → 0.1128987766`; knot crop `0.0582292769 → 0.0582303411`);
  that production candidate was reverted.
  Reproduction is documented in `diagnostics/README.md`.
  Acceptance remains matching the six
  per-interval call distribution and improving the rendered plates together.
- [ ] **S104 recursive cut geometry.** On the first mismatched row, source and
  Typst use the same subdivision request and matching width thresholds, yet
  the first divergent shared depth-4 cut is x=39.539 mm versus x=44.895 mm.
  Outer `minStrokeWidth` now uses the source's dimensional 16.16 rounding.
  On a separate 29.696 mm row this moves the root cut from 0.000998 mm to
  0.000323 mm from the source point, with source cut time 1.65522766 versus
  Typst 1.65519714. The matched M4/M6/M11 renders are unchanged; M9 and S105
  improve slightly. S104 hatch RMSE rises only 0.00000344, while its depth-2
  endpoint remains 0.000000034 mm below threshold and still misses a source
  split. Keep the source threshold rounding and trace width propagation at
  the recursive cut before claiming the row tree is matched.
  Pair the source cubic/template knots with the exact Typst sample intervals
  used by `cutPathTime`; derive the selected crossing and midpoint from that
  paired geometry. A thin-only rounded-cubic probe matched the cut within
  0.0017 mm but regressed whole S104 RMSE (`0.207029 → 0.207733`) and hatch
  crop RMSE (`0.075285 → 0.079011`), while moving all-row thin-node count
  farther from source (`1577 → 1490`, source `1696`); it was reverted.
  The source trace now records both ray cubics and raw MetaPost
  `intersectiontimes` pairs. Replaying Fiziko's forward/reverse preference
  and midpoint-nearest selection reproduces all 19 source cuts on the target
  row, including node 172 (`1.50017` at x `52.61568` versus the other hit at
  x `35.07321`). This isolates the remaining mismatch to low-level
  `intersectiontimes` behavior and Typst's recursive subpath parameterization.
  An integer 16.16 packet-search model now reproduces 67/76 raw
  forward/reverse hit pairs within one path-time unit on this row, including
  all four for node 172. Raising its depth from 17 to 18 accounts for five
  additional pairs. The replay now models the source's packed `max_t`
  progression, saved approximation, backtrack timeout and packet-stack guard.
  Treating stack-limit overflow as a failed packet branch that can resume
  sibling search instead of terminating the cubic leaves both recorded rows
  unchanged at 67/76 and 15/20. Nine raw pairs still disagree: eight
  source hits lie within 1/64 path-time of a cubic endpoint, and one is an
  interior source hit. A new trace records exact 16.16 intersection times;
  evaluating node 173's recorded cubics at its source pair leaves an estimated
  residual of about 2.16/0.5 raw coordinate units. This supports a
  near-overlap/precision-fallback explanation, but fixed-point overlap
  evaluation still differs on the nine raw pairs; no production change is
  justified yet. A separate
  depth-only comparison also leaves both rows unchanged at 67/76 and 15/20,
  respectively, so a larger terminal depth is not a substitute for the source
  state transitions. The trace replay is documented in
  `diagnostics/README.md` and implemented by
  `diagnostics/replay_s104_thin_intersections.py`.
  Acceptance: match the target node and terminal leaf/dash tree, then improve
  paired row decisions without the known flat-crossing node-count explosion
  or this all-row raster regression.
- [ ] **Wood contour brush geometry and traversal.** M9's source cLine width
  ranges now match to at most 4.91e-5 source field units, but source contour
  calls remain approximate. An automated source/Typst pairing now finds the
  same contour level after accounting for `isoLines`' sign convention and
  field scaling; its reversed 19-cell sequence is exact, its path mean/max
  distance is 0.108/1.315 mm, and reversed per-cell width ranges differ by
  1.54e-5 mean and 4.92e-5 max. A wood-only source fixed-point rounding
  candidate lowers same-grid M9 RMSE `0.212745 → 0.212742` and S105 RMSE
  `0.102450 → 0.102443`; its S105 coverage falls by 0.00015 percentage points,
  so retain the small pixel-error improvement as a measured tradeoff. The
  matched source brush has 37 outer nodes/19 leaves and 65 thin nodes/12 dash
  leaves. The Typst trace was corrected to pass `per: 0`, matching production
  `wooden-thing`; earlier 7/46 node and 10-dash figures came from accidental
  default resampling and are invalid. With `per: 0`, Typst has 11 outer nodes,
  48 thin nodes, 12 dash leaves and 24 RNG calls, matching the source's 12
  dashes/24 calls. The first outer cut differs by 0.00383 mm. Parent-aware
  pairing finds 42 node pairs, 34 within 0.1 mm, and 37/42 recurse/stop
  decisions agree. Five first divergences remain: two are within 0.0033 mm of
  source endpoints and differ at width-level/candidate validity; three later
  pairs have 0.115–0.501 mm endpoint error. The source root path is 17.2808 mm,
  versus Typst's 14.5469 mm, because its two boundary-cell endpoints are
  absent. Adding the exact source endpoints `(22,34)`/`(12,34)` moves the root
  length to 16.8732 mm while keeping the tree at 11/48 nodes, 12 dashes and 24
  calls; pairing remains 42 nodes and 37/42 decisions. However, 600 ppi M9 RMSE
  rises `0.212742 → 0.214067` even as ink coverage moves closer to source.
  S105 is effectively unchanged at 0.102443. The endpoint extension was
  reverted; closer length and call counts alone do not improve the source
  image. (An earlier endpoint guess used the wrong boundary coordinate and is
  excluded from these measurements.)
  A one-scalar-unit level-bias candidate fixes the first close branch, but the
  corrected `per: 0` trace worsens tree agreement: paired nodes fall 42 → 40,
  pairs within 0.1 mm fall 34 → 30, decisions 37/42 → 36/40, and dash leaves
  12 → 11. Its raster candidate improved M9 RMSE `0.212740 → 0.212504` but
  regressed S105 `0.102443 → 0.102450` and increased M9 coverage error; keep it
  reverted. Continue pairing exact width-template knots and endpoint candidates,
  without global threshold changes.
  The source trace now also records the width-template cubic controls for each
  thin call. On call 10, the first/last template widths agree with the logged
  0.05563/0.04977 mm endpoints. The source builds this template on integer
  `offsetPathTime` samples of `iL`, then recurses over `reverse(iL)`; Typst
  currently interpolates widths by normalized arc fraction. Pair these time
  domains and path orientations explicitly before changing the width law. A
  regenerated source/Typst trace confirms the close call-10 divergence: the
  source `w2` is 0.04979 mm and stops as a dash, while the paired Typst node
  spans 0.0497870–0.0556436 mm and recurses at target width 0.0527153 mm.
  Their endpoint widths still pair within 0.000018/0.000014 mm in reversed
  spatial order. This points to the interior width-template/path-time mapping
  on that branch, not an endpoint-width mismatch; it does not establish a
  safe production width-law change. A Hobby width curve sampled at four
  points per contour edge regressed matched 600 ppi RMSE on M9
  (`0.21274033 → 0.22116264`) and S105 (`0.10244255 → 0.10595469`) because
  densification changes the brush's path-time grid; it was reverted. The
  continuous source width profile must reach recursion while preserving the
  contour's original path-time parameterization. A second attempt queried a
  Hobby width curve directly at recursive cuts without densifying the path;
  it lowered source-tree agreement (42 → 40 paired nodes, 34 → 24 close pairs,
  37/42 → 31 decision matches) and regressed M9/S105 RMSE to
  `0.21301552`/`0.10315715`. That generic spline and callback were reverted:
  use the traced source cubic controls and their own parameter domain instead.
  A fresh source trace found a more basic brush-input difference: `woodBlock`
  clips its intermediate picture only after `isoLines` runs `brushGenerate`
  on the full `cLine` path. Typst currently clips the contour before width
  evaluation and recursion. On the first M9 contour, source has 22 path points
  and a 17.28086 mm outer root, while the paired Typst path has 20 points and
  a 14.54685 mm root; the source endpoint extensions transform beyond the
  block's `y=33` edge. A candidate appended these boundary cells, brushed the
  extended path, and clipped final ink to the rectangle. It moved the Typst
  root length to 16.87318 mm and RNG calls to 22 versus 24 source calls, but
  parent-aware decisions fell from 37/42 to 34/40 and the root cut remained
  0.00383 mm from source. The candidate worsened tree alignment. At 600 ppi,
  M9 regressed `0.212742 → 0.214788`; S105
  improved `0.102443 → 0.102240` while ink coverage moved farther below
  source. The renderer candidate was reverted. Source-order clipping remains
  established; a future attempt must also match the source width-template and
  recursive cut behavior and pass both plate gates. Detailed measurements are
  in `diagnostics/README.md`. An earlier vertex comparison claimed the final
  two in-bounds source vertices were reversed in Typst. That claim is
  superseded by the current source-walk trace: its first M9 path ends
  `(12.85438,33) → (13,32.86746) → (12,34)`, in the same order as the source
  trace's `(12.85017,33) → (13,32.86281) → (12,34)`. The two contour
  intersections still differ by about 0.004–0.005 mm, but this is a position
  residual, not a direction reversal. The source trace's final recursive
  cells are `(0,22) → (-1,22) → (-1,12)` in source grid coordinates; the last
  two are out of bounds and return their grid coordinates `(i,j)`, which
  transform to `(22,34)` and `(12,34)`. `contour.typ` has an iterative
  `source-walk` mode that
  follows cLine's source scan, edge order, visited-cell choice and directed
  branches without recursive Typst calls; `wooden-thing` uses it for source
  fields. On the first M9 path it emits 22 points in source order, with mean/
  max point-to-source distances `0.00197/0.00465 mm`; the brush root is
  `17.2651 mm` versus `17.2808 mm` source. At 600 ppi, M9 RMSE improves
  `0.212742 → 0.212436`, and ink coverage moves `3.7497% → 3.7804%` toward the
  source's `4.2032%`. A matching same-checkout S105 baseline gives whole-page
  RMSE `0.102443 → 0.102628`; block crop is unchanged at `0.127927`, while
  surface crop changes `0.077655 → 0.078106`. Ink coverage moves
  `0.6960% → 0.7004%` toward `0.7405%`. Keep the source traversal because its
  path topology follows the pinned source and M9 improves, with the S105 crop
  tradeoff recorded.
  A direction-only reversal using the old arc-width profile regressed M9
  `0.212436 → 0.213024` and was reverted. The cLine replay maps every first-path
  segment to its source state: `iL` descends `st=19…-1`, while
  `reverse(iL)` consumes `st=-1…19`; both exterior segments have zero range.
  `stroke-ink` now optionally samples widths at normalized path time, and
  `_wood-source-width(source-time: true)` builds the reversed profile with the
  terminal two samples set to the source callback's special value 1. On the
  full diagnostic path, its 22 width samples match MetaPost `CLWIDTH` to
  `2.93e-5 mm` mean / `9.91e-5 mm` maximum. Source/Typst tree pairs within
  0.1 mm rise `33/42 → 36/42`; paired recurse/stop decisions remain `37/42`,
  while nearby dash leaves rise `7/12 → 8/12`.
  Using that reversed path-time profile on the clipped production paths lowers
  600 ppi M9 RMSE `0.212436 → 0.211560`, while ink coverage changes
  `3.7804% → 3.7120%` (source `4.2032%`). S105 full RMSE improves
  `0.102628 → 0.102148`; block crop remains `0.127927`, surface crop improves
  `0.078106 → 0.076936`, and surface ink coverage moves `0.5518% → 0.5309%`
  toward `0.4892%`. Keep this source-time profile with the M9 coverage tradeoff
  recorded. Production still clips the centerline before brushing, so its
  endpoint state sequence is shorter than the full source `st` range. A
  rectangle-only full-path-brush-then-clip trial preserved S105 exactly but
  regressed all four M9 panel crops (whole RMSE `0.211560 → 0.212807`); it was
  reverted. The remaining gap is matching the source's endpoint state and
  clipping order without changing the brush's recursive tree adversely.
  Brush recursion remains open (11 outer/48 thin nodes versus 37/65 source),
  and only the full diagnostic contour currently has the complete source-time
  state mapping.
  Typst thin-node traces now include endpoint widths: at paired call 10 they
  match the source endpoints in reversed spatial order within
  `0.000018/0.000014 mm`. This rules out a wholesale orientation error there;
  the level-9/10 disagreement is sensitive to local cell-range values.
  Compare the source and Typst cell-corner samples before considering a local
  correction; the global level bias remains reverted.
  `CLVFIX` now captures exact 16.16 source values for the first 72 lattice
  samples. Against Typst after undoing its 24x contour scale, mean/max absolute
  errors are `1.23e-5/6.10e-5`; source cell `(3,16)` has range `0.033203125`
  versus Typst `0.033157349`. This supports investigating source arithmetic at
  field corners, with M9 and S105 renders required before retaining a change.
  A field-operation 16.16 probe improved the 72 grid samples (mean/max
  `8.48e-6/4.58e-5`, 37 exact matches versus 29), but regressed 600 ppi M9
  `0.212742 → 0.212848` and S105 `0.102443 → 0.102495`; it was reverted.
  A targeted source trace now shows the end-intersection residual is present
  in the level inputs: source's first-block maximum is
  `13632/65536 = 0.2080078125`, versus Typst `0.2080357144`; the adjacent
  source edge corners are `10204/65536` and `10758/65536`, while Typst's
  24x-scaled samples convert to `0.1557307` and `0.1641486`. The source level
  is `-10675/65536`; Typst's level converts to `0.1629227866`. The source
  jitter is `226/65536`, and the Typst RNG value at offset 204
  (`0.6616821289`) rounds to that same value through `uniformdeviate(1/192)`,
  so the random-call position matches. This explains the approximately
  `0.004–0.005 mm` intersection offset without a path-order mismatch and
  localizes the remaining level error to maximum-field arithmetic. At the
  maximum cell `(6,42)`, source `wField`/column offset are
  `0.20356750/0.00444031`; Typst gives `0.20359104/0.00444468`. The column
  random sample at index 176 rounds to the same `291/65536` source offset, and
  the first accepted knot matches within `0.0003 mm`, so the residual is in
  `wField` evaluation. At this cell the source cumulative knot terms are
  `0.01373291, 0.23362732, 0.24186707, 0.23954773, 0.27470398`. Typst terms
  with source-rounded `detail`/`rho` constants are
  `0.01373820, 0.23362618, 0.24187107, 0.23956109, 0.27472421`, exposing the
  remaining error in intermediate operations. A source-constant candidate
  rounded `woodBlockDetail` and `woodBlockYRdensity` to 16.16 while leaving
  other field operations floating point. It moved the first M9 crossing
  toward source (`12.85438 → 12.85284 mm`, source `12.85017 mm`), but regressed
  M9 RMSE `0.21156032 → 0.21170117` across all four panel crops and S105
  `0.10213793 → 0.10214326`; block/surface crops became
  `0.12791856/0.07693501` versus `0.12790793/0.07693635`. Ink coverage moves
  slightly closer, but the production candidate was reverted. Reproduce
  `wField` intermediate arithmetic in a max-only evaluator before trying a
  level-only correction; the earlier full-field 16.16 candidate also
  regressed both plates.
  A follow-up traces the fixed-point minimum at `(33,29)`. Source cumulative
  knot terms are `0.01546, 0.01967, -9.91542, -9.90645, -9.88245`; the
  diagnostic fixed-point port gives `0.015457, 0.019668, -9.915268,
  -9.906296, -9.882294`. The first visible difference is the third knot:
  source radius/angle decode to `20/256+40/65536` and
  `716/256+119/65536` from MetaPost's 16.16 trace, while the port gives
  radius `0.078812` and angle `2.798401`.
  The final field differs by about `0.00015`, consistent with the prior grid
  minimum discrepancy. A diagnostic-only probe now reproduces the port's
  terms; no production field or contour-level change is justified until the
  knot-coordinate conversion and source `angleRad` rounding are matched.
  Pairing the first five accepted `WKCAND` positions with the Typst knot
  export shows 0.0001–0.0005 mm coordinate residuals. A candidate that rounded
  source knot-bound, random-product, offset and coordinate operations to 16.16
  changed M9 RMSE `0.21156032 → 0.21156152` and S105
  `0.10213793 → 0.10213547`; S105 block improved `0.12790793 → 0.12790289`,
  while its surface crop regressed `0.07693635 → 0.07693717`. It did not
  consistently reduce the paired knot-coordinate residuals, so the candidate
  was reverted. Trace the source random product and shifted grid coordinate
  separately before another knot-generation change.
  A second candidate formed the source `mm`/`cm` point constants before
  rounding the bound and final coordinate. The new `WKRAND` trace confirms
  this does not remove the coordinate residual: paired point-unit
  residuals remain around `0.00008–0.00041 mm`, and 600 ppi RMSE regresses on
  both M9 (`0.21156032 → 0.21161418`) and S105
  (`0.10213793 → 0.10214069`). This candidate was also reverted. Keep the
  added candidate-only `WKRAND` source trace; its 57 existing `WKCAND` records
  are byte-for-byte unchanged, so the instrumentation preserves the source
  random sequence. The next arithmetic probe should expose the exact shifted
  `wKnot` pair before the `woodBlockRes/detail` output conversion.
  `WKRANDFIX` now captures the exact 16.16 bound/product pair. For the first
  candidate, MetaPost returns `1.72431946` from bound `6.84989929`; multiplying
  the old 16.16-rounded Typst random `0.25172424` by that bound gives
  `1.72428894`, two 16.16 units low. Retaining the full subtractive-stream
  fraction (`0.2517283261`) and rounding only the product reproduces the
  source result exactly, consistent with MetaPost's documented
  `uniformdeviate`/`take_fraction` path ([MetaPost source manual, §163](https://tug.org/metapost/src/manual/mp.pdf)).
  This brings the first five candidate positions within
  `0.000015 mm` of the source. Yet the knot-only raw-fraction render regresses
  M9 RMSE `0.21156032 → 0.21169146` and S105
  `0.10213793 → 0.10215109`; applying raw fractions to column jitter also
  regresses both plates further. Both production candidates were reverted.
  The coordinate trace is now source-accurate, but the continuous field and
  contour interpolation currently do not preserve the raster gain; keep the
  exact RNG product as a diagnostic oracle until the field evaluator is paired
  at the same source grid points.
  The diagnostic now derives those raw-fraction knot positions from the seed-1
  subtractive stream and the traced 28-call brush consumption per accepted
  knot, then feeds them to the 16.16 `wField` evaluator. Its first three
  cumulative knot terms reproduce the source trace exactly. It also records
  the first block's source column jitter. Across
  the 72 traced source samples, 58 field values match exactly after removing
  the corresponding column jitter; mean/max absolute field error is
  `3.60e-6/3.05e-5`. The fixed-point minimum and maximum cells also reproduce
  the source `wField` values exactly. Feeding these source-grid extrema into
  contour-level generation while retaining the continuous Typst field still
  regresses M9 RMSE `0.21156032 → 0.21185228` and S105
  `0.10213793 → 0.10304308` (surface crop `0.07693635 → 0.07925067`); that
  production candidate was reverted. The field samples now have a useful
  source oracle, but contour-level phase or grid-to-continuous mapping remains
  wrong for the raster. `CLCOL` and the 72-sample evaluator are diagnostic
  additions only.
  A narrow 16.16 rounding of only the sampled maximum changed M9 RMSE
  `0.21156032 → 0.21154594`, but S105 regressed `0.10213793 → 0.10213956`,
  including both block/surface crops (`0.12790793/0.07693635 →
  0.12790896/0.07693895`). M9 ink coverage was effectively unchanged, and its
  first-path intersection moved farther from the source point. The production
  candidate was reverted; reproduce the source `wField` maximum arithmetic
  before trying another level adjustment.
  A narrower contour-only probe rounded edge parameters and physical crossing
  points to 16.16 while leaving field sampling untouched. It regressed same-
  checkout M9 RMSE `0.21155798 → 0.21162015`; S105 changed only
  `0.10213802 → 0.10213798` (block `0.12790809 → 0.12790793`, surface
  `0.07693635 → 0.07693648`). This candidate was also reverted.
  The source `fullcircle` cubic
  sampler matches within 3.1e-5 and reproduces ring counts; feeding those
  rings into the current band renderer worsened RMSE, so keep that candidate
  reverted.
  Acceptance: match per-contour leaf/call order and improve M9 contour crop
  without regressing S105's independently verified field/width behavior.
- [ ] **M11 coast brush sampling.** The projected coast paths, seam merging,
  source five-step horizon crossing, and closed contours already agree in arc
  time within 0.001 fullcircle units. The spherical normal now uses the source
  radius exactly, `|point - center| / d` (where `d` is the globe diameter),
  and its first traced mass-4 normal agrees with MetaPost within 0.001 per
  component. Correcting Typst's `atan2(x, y)` call order also restores the
  source mass-4 normal direction. The focused source/Typst root cuts now split
  mass 4 into 14.296/13.938 mm children (source 14.292/13.925 mm) and mass 2
  into 139.786/107.763 mm (source 139.59/107.88 mm).
  The 600 ppi globe ink coverage moves from 26.443% to 26.353% against 25.940%
  source, while globe RMSE changes from 0.188748 to 0.189896 and whole M11
  RMSE from 0.112661 to 0.112950. Keep the source-equation correction with
  this raster tradeoff recorded. Recursive cuts and random-call order remain
  open: turning `_source-rounding` on for coast brushes alone regressed the
  same-checkout M11 RMSE `0.11295018 → 0.11302680` and globe crop
  `0.18989608 → 0.19019925`, although globe ink coverage moved closer by
  0.01187 percentage points. Rounding only the lightness-derived width also
  regressed RMSE (`0.11295018 → 0.11298345` whole, `0.18989608 → 0.19002779`
  globe) despite slightly closer ink coverage; that candidate was reverted.
  Enabling the library's arc-based width interpolation for coast brushes
  changed sampled widths slightly but left all six tree counts unchanged and
  produced identical whole/globe RMSE (`0.11295018`/`0.18989608`); that
  candidate was reverted too.
  Source/Typst calls remain 27/52. A parent-aware diagnostic corrects the
  previous mixed node/leaf count: visible source/Typst trees contain 106/48
  recursion nodes, with 46 paired nodes, 37 matching recurse/stop decisions,
  and 22 pairs within 0.1 mm. Mass 2's first paired divergence is at depth 5:
  source cuts the q path at 3.95935, 0.160 mm from its endpoint, while Typst
  finds no crossing at the corresponding width boundary. The source q cubic
  controls are linear; the observed difference points to near-endpoint
  `intersectiontimes` behavior. Source trace values are rounded in the log, so
  the new instrumenter now captures the exact 16.16 input. At the first M2
  divergence the target equals the q cubic's final width (`0:40:97`), yet
  MetaPost returns a forward hit at q time `3:245:152` (3.95935059), about
  0.160 mm before the endpoint; the reverse ray has no hit. Exact q width
  controls are `0:41:114`, `0:41:23`, `0:40:188`, `0:40:97`. This establishes
  a near-endpoint `firstIntersectionTimes` behavior but does not yet isolate
  its low-level cause or justify a production special case. A reduced probe
  produces raw forward pair `(0.99014, 0.95935)` and reverse pair `(1, 0)`;
  Fiziko selects the forward pair. The current integer packet replay predicts
  `(0.999996, 0.999996)`, missing the source result. MetaPost 2.11 documents
  a best-pair fallback after 5000 unsuccessful bisection backtracks. An
  attempted reordering of the replay's stack guard to the start of each
  packet visit, based on the source's control flow
  ([`mp_cubic_intersection`](https://github.com/TeX-Live/texlive-source/blob/branch2025/texk/web2c/mplibdir/mp.w#L15047-L15103)),
  reduced the fresh S104 target-row matches from 67/76 to 31/76. The assumed
  level-19-to-stack-bound mapping is therefore wrong; that edit was reverted.
  The updated source trace still independently replays all 19 cut choices,
  while the fixed packet classification remains 67/76. A diagnostic sweep of
  guard depths 15–23 stays flat at 67/76; truncation, floor, nearest-away and
  nearest-even packet halving also all stay at 67/76. These results move the
  remaining investigation toward packet overlap arithmetic rather than guard
  depth or half rounding. `audit_s104_fixed_encoding.py` checks the fresh
  source trace's 132 cubic controls, 76 ray endpoints and 38 fixed raw-hit
  pairs against their decimal companions: maximum differences are
  `7.28e-6`, `6.59e-6` and `6.81e-6` respectively, with no low-byte carry
  anomalies. This rules out a large serialization mismatch; reproduce the
  source overlap operations directly before changing the packet model.
  The exact-level sweep finds no hit from −8 through −1 raw 16.16 units, the
  early `0.95935` hit at zero, `0.99634` at +1, then `0.99268` at +2; later positive
  offsets track the shallow cubic root. The isolated +1 excursion shows that
  even a local monotone endpoint rule would be wrong. Model the
  best-pair fallback against this probe and known S104 endpoint cases before
  changing production recursion. Continue pairing the Typst interpolation
  interval and source cut inputs on masses 2 and 4.
  The endpoint behavior is reproduced independently of coast traversal. The
  remaining implementation gap is matching this fixed-point cubic
  intersection behavior in the Typst brush model.
  Acceptance:
  improve paired leaf/call traces and the globe
  render together.

The following are deliberately not implementation tasks until new evidence
changes their status: the M11 radial-y shading candidate (it moves lane call
counts closer but worsens M11/M4/M6 crops); S104 flat-interval crossing (it
nearly doubles thin-recursion nodes); density-only brush tuning (it trades
RMSE against ink coverage without improving both); and replacing M9's connected
contours with the sampled source rings (the measured render regressed).

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
   centerline angle differs by 0.02009 rad. Fitting each four-interval cubic
   from the fixture's five 1/16 samples now reproduces the traced source
   controls within 0.000049 mm and tangents within 0.000156 rad maximum. The
   production candidate lowers knot RMSE to 0.058819 and whole M11 RMSE to
  0.112661. The corrected source-rounded lane diagnostic counts 224/212
  source/Typst calls, so lane-width recursion and the short dash-phase restarts
  still need path-paired leaf traces. The latitude mode still approximates the
  source's two separately masked shading layers and random width law.
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
   approximate. The source wrapper records coast RNG calls by landmass as
   `[6, 15, 0, 3, 1, 0, 1, 1]`; the zero entries are empty fallback paths.
   Typst's current 348/580 layer dash-call totals are not comparable because
   they omit recursive brush draws and mix coastline work with the masked
   latitude layers. Per-mass leaf and callback tracing is still needed before
   a source stream offset can be inferred. The production-path trace now
   records source/Typst RNG draws by visible mass as `6/36`, `15/42`, `3/8`,
   `1/0`, `1/4`, and `1/2` (source/Typst order for masses 1, 2, 4, 5, 7, 8).
   Thin recursion nodes are `15/37`, `57/41`, `31/7`, `1/0`, `1/3`, and
   `1/1`. The mismatch is localized rather than a uniform stream offset:
   masses 2 and 4 have many more source nodes, while mass 1 has more Typst
   nodes. Enabling 16.16 rounding in the Typst coast trace increases its total
   from 92 to 112 calls, so the change was reverted. Pair source cut parameters
   and width-cubic ranges on masses 2 and 4 before changing the coast width law
   or stream. Source `offsetPathTemplate` uses cumulative arc length as q's x
   coordinate, so `cutPathTime`'s midpoint is the arc-length midpoint; the
   disagreement lies in width-cubic crossings, not screen-x versus arc
   selection. A screen-x midpoint selector briefly improved the 600 ppi
   scores, but was removed after the upstream coordinate definition showed
   that selector used the wrong axis. On mass 4, source and Typst root targets
   agree to 0.00002 mm, but source child lengths are 14.292/13.925 mm versus
   Typst 8.974/19.260 mm.
   The source trace now emits q cubic controls (`S101-CUBIC`) around each cut.
   A fixed stream offset tested with the prior projection and again with
   closed contours was reverted.
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
