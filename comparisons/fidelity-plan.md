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
| M9 wood panels | 0.21145 | 4.203% → 3.709% | The comparison reproduces its source driver's 1 mm `woodBlockRes`, source-ordered fractional contour levels, and source-space knot field. Mask-aware extrema for `wooden-thing` contour levels reduce whole-plate RMSE from 0.21156 to 0.21145; top-left/top-right/bottom-left/bottom-right crops are 0.19467/0.23371/0.23918/0.17064 (the prior bottom-right crop was 0.17069; right-top regresses by 0.00008). Panel stream offsets remain `[0,1456,2823,4120]`. The focused trace now uses the same inset mask; all 19 in-grid cells match, with mean/max path error 0.00197/0.00465 mm. A raw-RNG, source-rounded bounds evaluator reproduces M9's source extrema and exact first contour level; the focused path falls to 0.000530/0.001721 mm error, but the paired M9/S105 candidate regressed full RMSE to 0.211578/0.102440 and was reverted. S105 block crop improves slightly while its surface crop regresses 0.075818→0.077823. The first-panel baseline level remains 3.910147 versus source `CLLEVELFIX` mapped to 3.909302; the level input now matches, so remaining rendered error is in the sampled contour field and brush recursion. The source-fixed-level probe does not yet reproduce the full recursive tree. Like-for-like root q replay pairs all 21 segments; baseline x controls differ by mean/max 678.5/2922 fixed units, while width controls differ by 5.5/19. The source/Typst brush trees remain 37/41 outer and 65/52 thin nodes; both use 12 dashes and 24 random calls. |
| M10 mechanics and optics | 0.07533 | 0.645% → 0.810% | Source hanging-weight radius, 1/4 neck, shoulder expansion, 2 mm body offset and a 2*shadingDensity auricle capsule reduce spring/weight crop RMSE to 0.09878 (previous 0.09909); lens/rays remain 0.06302. Auricle interior shading remains approximate. |
| M11 globe, eye, knot, refraction | 0.11295 | 4.917% → 5.056% | The source-equation coast normal and corrected `atan2` argument order move focused 600 ppi whole-plate RMSE from 0.11266 to 0.11295; globe crop RMSE is 0.18990 (previously 0.18875), while globe ink coverage moves closer from 26.443% to 26.353% against 25.940% source. For mass 4, the root recursive cut now splits 14.296/13.938 mm, matching source 14.292/13.925 mm. The fitted knot center cubic controls from 1/16 source samples match traced MetaPost controls within 0.000049 mm, with tangent error at most 0.000156 rad. Mask mode splits at crossing-interval midpoints, erases prior ink with higher tube silhouettes, and redraws hatch. Three crossing times match source times 6, 12, and 18. Knot crop RMSE is 0.05882, with knot ink 2.606% → 2.843%. The latest coast trace matches source brush-call totals on all six visible masses (54/54), but recursive trees and the cyclic-seam q time still differ; the post-rebase candidate has not passed the paired raster gate. The corrected source-rounded lane diagnostic counts 212 knot calls versus 224 source. Eye 0.23617 and refraction 0.08193 are unchanged. |
| S102 tube and shadow | 0.04909 | 1.818% → 1.887% | Matching the source's two smooth cubic tube joins with Hobby resampling at `per: 64` lowers tube-crop RMSE `0.07861 → 0.01821`; dark coverage is 0.6195% vs 0.6208% source. Sphere crop stays at 0.09110 and now dominates the residual. A source eight-knot lightness-only sphere probe moves dark coverage closer but regresses sphere RMSE to 0.10564; it was reverted. |
| S103 surface fills | 0.21682 | 3.240% → 3.342% | After matching the upstream four-row glass dash cycle, glass RMSE fell from 0.26279 to 0.23791 and coverage moved from 1.63× to 1.06× source. Opaque and gradient retain near-equal coverage (8.738% → 8.699%; 6.901% → 6.917%). |
| S104 flat surfaces | 0.20640 | 10.630% → 10.815% | Source-fixed 16.16 callback samples and source-rounded `pathSubdivide` points now build and split the width q template in source order. Its independent RNG cursor matches all 142 source subdivision draws, path-segment counts, brush-call totals, and absolute RNG offsets. The recursive q audit pairs 1,476/1,696 source nodes; on row 93 all 19 thin nodes pair and width controls match exactly, while q-arc controls differ by mean/max 10.780/16 fixed units. Same-run 600 ppi whole/hatch RMSE is 0.20640447/0.07183428; stipple is unchanged. Hatch ink coverage is 14.372% vs 14.066%, while whole-frame coverage is 10.815% vs 10.630%. |
| S105 wood block and surface | 0.10168 | 0.741% → 0.677% | The source-derived field uses the 1/3 mm `woodBlockRes`, fractional source contour levels and source-space landscape knot transform. Mask-aware extrema in the shared `wooden-thing` contour-level builder reduce whole-plate RMSE from 0.10214 to 0.10168; block/surface crops are 0.127908/0.075818 (block is unchanged; surface improves from 0.076946). Surface RNG offset remains 536. Full-plate ink is 0.6774% vs 0.7405%, while surface ink is 0.5097% vs 0.4892%; brush recursion and dash calls remain open. |
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

### Remaining work, ordered by evidence and dependency

The items below are the remaining implementation gaps with concrete next
steps. “Can improve” means the source behavior is known and can be implemented
or checked locally; the raster benefit still needs to pass the paired-plate
gate. Items that need a prerequisite are listed after it.

| Order | Gap | Concrete next step | Evidence and acceptance |
| ---: | --- | --- | --- |
| 1 | **M11 shadow lane callback remapping** | Carry source cubic controls and path-time ranges through `shadowCut`/`strand-knot` clipping; rebuild each fragment's `offsetPathSubdivide`/`offsetPathGenerate` boundaries and `interpath` lane controls; then map post-cut callback times to uncut `currentTubePath` direction, endpoint-clamped widths, and q arc origins through recursive children. | A diagnostic reconstruction from the original 1/16 M11 samples recovers the traced clipped center cubics within `0.000033 mm`, q2/q3 boundaries within `0.000065 mm`, and checked lane controls within `0.000041 mm`. A production trial using those lanes regressed same-run 600 ppi M11 whole/knot RMSE from `0.114799/0.078545` to `0.117208/0.097408`; M4/M6 remained pixel-identical. Keeping the old shadow silhouette and old tube edges while changing only inner lanes still gave knot RMSE `0.100047`, and the paired trace reduced six-interval brush calls from 212 to 192 versus 224 source. The production trial is reverted. A corrected callback-angle audit flips the lane cross-section sign on all 12 paired lanes: source angle error falls from 60° to 0°. With exact source cubic normals, that candidate reaches `0.114811/0.078650` whole/knot RMSE and 212 calls versus 224 source; adding source q2/q3 edges regresses knot RMSE to `0.079877`. Both trials are reverted. The source-arc-plus-width replay now recovers the three divergent thin trees exactly (40/40, 20/20, and 30/30 nodes); its `--` q controls are reconstructed from knots, not injected. The next step is to generate those post-`shadowCut` arc and callback-width knots from production lane geometry/time mapping, then integrate only when source call vectors and M11/M4/M6 image gates pass. Older replay evidence remains: injected source arcs reproduce q controls, but quarter-fit replay trees still miss source calls; source green-angle replay from the uncut centerline matches within `0.0054°` max. |
| 2 | **S104 scanline geometry, root q construction, and recursion** | Align source scanline endpoints and fixed-time subdivision points first; then carry their q template through outer cuts and thin recursion without changing the row schedule. | The retained source-fixed callback candidate pairs all 142 rows: subdivision draws, brush calls (`1516/1516`), path-segment counts, and absolute RNG offsets match the pinned source. On row 93, all 19 source thin nodes pair and width controls are exact; source-rounded `pathSubdivide` points improve q-arc controls from mean/max `10.932/17` to `10.780/16` units. A fresh trace confirms 1,476/1,696 full-tree node pairs, 1,213 exact width-control nodes and q-arc residual mean/max `58.733/933` units. The row-93 outer root cut parameter matches exactly (`55358/65536 = 0.8446960449`). New source bp-coordinate records show q arc increments agree with source point-to-point chords within one fixed unit, while source points differ from Typst same-time row samples by `0.00008–0.00014 mm`; a reproducible audit gives mean/max point error `0.000105669/0.000144343 mm`. The first mismatch is in scanline endpoint/subdivision geometry before the outer cut. A native MetaPost `subpath (0, 2.40022)` replay matches node 164's child q controls exactly, confirming this branch's thin split arithmetic. Injecting traced source q cubics as a local oracle gives row 93 exact controls for all 19 nodes; row 99 gives 17/19, with two unmatched leaves localized to a half-time child split that rounds one width unit high. Same-run 600 ppi whole/hatch RMSE is `0.20640447/0.07183428`; stipple is unchanged. Preserve the exact random schedule and require the full-tree plus image gate. Do not revive the rejected fixed-scanline or sampled-q integrations. The exact source-q replay remains a local oracle for node 172's `1.50017` cut at x `39.539 mm`.

| 3 | **M11 knot phase restarts in production** | Carry source callback q-width knots and phase restart points into the real lane renderer, preserving exact source call offsets. | The source-rounded replay matches all 19 leaves/38 calls on k=6, but it is diagnostic-only: current production trace passes no q curves to `_ink-loops`. A temporary candidate that derives fixed q widths from sampled lane widths changes aggregate calls 212→208 against source 224 and leaves per-interval call-vector L1 error unchanged; it was removed without a raster trial. Require source callback knots, lane call vectors, and M11/M4/M6 image gates before retaining an integration. |
| 4 | **M11 coast brush callbacks and recursion** | Propagate source-compatible child q endpoints/cubic controls through recursive cuts, beginning with mass 1's terminal seam and mass 2's narrow endpoint crossings. | A fresh full source/Typst trace after cubic-time inversion reports source/Typst thin-node counts `15/17`, `57/57`, and `31/31` for masses 1/2/4. Parent-aware decision agreement is `14/15`, `26/31`, and `31/31`; root endpoint error is at most `0.00014 mm`. Mass 4's former 31/7 mismatch is resolved without changing source brush-call totals. Mass 1's remaining terminal seam pairs source stop at q-time `0.99817` with Typst recurse at `0.98076`; mass 2 has five decision mismatches despite equal node totals. Paired q starts differ slightly before intersection testing, so do not change the global solver tolerance. Earlier width-arithmetic, uniform seam-time, and fixed-arithmetic candidates remain rejected: they regress other mass trees or the paired raster. The next useful correction is source-faithful child-q endpoint and cubic-control propagation, followed by all-six-mass tree checks and the paired M11 raster gate. |
| 5 | **Tube cross-section shading and lane calls** | Resolve the source-vs-Typst inner-lane width/lightness law by paired `(call, lane, sample)` records, then address the compensating per-interval call distribution. | All six intervals and endpoints pair; calls are source `14/58/54/42/38/18` vs Typst `10/38/40/52/50/14`. Unshadowed calls 1–3 match width/lightness within `0.000002 mm`; using source shadow labels for calls 4–6 gives aggregate width MAE `0.001036/0.001642/0.000382 mm` with source/Typst sample distance `0.000085/0.000087/0.000008 mm`. The remaining residual tracks post-cut geometry/time correspondence, so another global lightness change is not supported. Normal/lightness production candidates previously regressed M11/M4/M6 renders; retain only geometry or callback corrections that clear all three image gates. |
| 6 | **Wood cLine recursion and call order** | Reproduce source mask-aware contour-level bounds and exact random level draw, then carry source `st`/cell-range state and callback parameterization through recursive brush cuts; validate first on M9 and then S105. | The fresh production-matched M9 trace has 41/52 outer/thin nodes versus source 37/65; both consume 24 random calls and draw 12 dashes. The diagnostic source-q replay pairs 46 thin nodes, 43/46 recurse/stop decisions, and 11/12 dash endpoints within 0.1 mm, but integrating that forward-arc template into production regressed M9 RMSE (`0.21138138→0.21201468`). Replacing the first diagnostic contour level with the source fixed trace reduces contour point error fivefold and root q arc-x error about 6.7×, but does not change the tree counts; reproducing the source mask range and random level generation is now the first actionable step. Retain a production change only after M9 and S105 crop gates pass. |
| 7 | **Wood knot brush offset/leaf geometry** | Separate the source cubic `fullcircle` geometry from its eight-knot width template, then compare offset boundaries and leaf endpoints before touching the band renderer. | The pinned cubic sampler reproduces source ring counts, but using its rings in production worsened M9 RMSE and coverage. Geometry is a known source behavior; production rendering remains gated on M9/S105. |

**M9 raw-RNG knot-coordinate rounding probe (2026-11-05, reverted).** The
source-rounded extrema diagnostic reaches the pinned M9 minimum/maximum only
when it is given raw-fraction knot coordinates. A production candidate formed
each accepted knot coordinate as a separately 16.16-rounded raw RNG product
plus the rounded negative half-radius offset, while leaving the rounded random
stream, column jitter and call cursor unchanged. Same-checkout 600 ppi renders
against the current baseline show mixed region results: M9 full RMSE improves
`0.211452985 → 0.211396935`, with top-right/bottom-right improving
`0.233712567/0.170635231 → 0.233487254/0.170547375`, but top-left/bottom-left
regress `0.194674703/0.239184657 → 0.194677923/0.239266706`. S105 full/block
regress `0.101683758/0.127907934 → 0.101694601/0.127932279`; surface improves
`0.075817840 → 0.075811201`. The candidate is reverted because the block
regression and two M9 crop regressions mean the coordinate rule does not yet
clear the paired wood gates. Continue by tracing the source fixed-point
conversion of accepted knot coordinates and test it against all four M9 panel
streams and both S105 regions before changing production again.

**M9 fixed-coordinate replay follow-up (2026-11-05, reverted).** The source
trace records each raw `uniformdeviate(bound)` result and the resulting
accepted `WKCAND` coordinates. Baseline and source both accept `5/4/4/4`
knots on the four panels with source offsets `0/1456/2823/4120` and Typst
field random counts `204/174/174/174`; the baseline positional mean/max error
per panel is `0.000306/0.000505`, `0.000236/0.000326`,
`0.000278/0.000450`, and `0.000191/0.000292 mm`. Replaying the source's
intermediate rounding of `woodKnotRadius`, `woodBlockDetail`, the detail-space
bound, random product, shift, and conversion back to millimetres preserves
all four accepted sequences and reduces their positional mean/max error to
`0.000001655/0.000002168`, `0.000001397/0.000002049`,
`0.000001541/0.000002688`, and `0.000002167/0.000002641 mm` (the source trace
prints only five decimal places in bp). The production replay preserves each
field call cursor, but a fresh same-run 600 ppi pair regresses M9 full RMSE
`0.211452985 → 0.211531168`; top-left,
top-right and bottom-left crops regress `0.194674703/0.233712567/0.239184657
→ 0.195252499/0.233848533/0.239283558`, while bottom-right improves
`0.170635231 → 0.170035834`. S105 full/block regress
`0.101683758/0.127907934 → 0.101692659/0.127928593`; surface improves
`0.075817840 → 0.075811463`. This source-exact geometry replay is reverted:
all four accepted-knot sequences and RNG offsets match, yet M9 and S105 render
gates regress. The remaining wood gap is therefore in how source field values
and resulting contours are evaluated around these accurately paired knots,
not in missing knots or panel cursor order.

The associated fixed-point `wField` probe now includes the same column jitter
as source `CLVFIX` and uses source fixed-point knot coordinates. Compared at
the raw field scale (without the production contour's factor of 24), it pairs
55/72 grid samples exactly, with mean/max absolute error
`4.03e-6/3.05e-5`. This confirms the source arithmetic oracle is within two
16.16 units on the sampled grid, but it does not yet show that replacing the
production continuous field improves the contour raster; previous full-field
and max-only production candidates still regress one or more M9/S105 regions.

**M11 coast cubic callback trial (2026-11-05).** The production Typst trace
rebuilt from the current checkout pairs 7 of 31 source thin nodes on mass 4,
with 6/7 recurse/stop decisions agreeing; masses 1/2/4 are
17/57/7 Typst nodes against 15/57/31 source nodes. The paired mass-4 parent
q cubics begin at source fixed `(3003270, 10336)` and Typst
`(3002304, 10337)`, and their selected q times differ (`0.05556` vs
`0.43423`). Source q knots for the child number 9, as do Typst's, but their
first endpoints differ by 15,864 fixed x units and 9 width units. A diagnostic
extension to `compare_m11_coast_brush.py` now prints the q controls and knots
at the first parent-aware branch divergence, avoiding the earlier ambiguous
depth-only pairing. A production trial evaluated horizon callback points from
the exact fullcircle source-time map instead of interpolated rendering
samples; this left mass 4 at 7 thin nodes and expanded mass 2 from 57 to 111,
so it was reverted before raster comparison. Exact callback point evaluation
alone is not sufficient. The ancestor trace now shows where the discrepancy
enters: the root q cut agrees in time (`30.23958` vs `30.239578`) and its
selected cubic has exact widths, with x controls differing by at most 49 fixed
units. At depth 1, however, the selected q cubic already starts one fixed
width unit too high in Typst (`10331` vs `10330`); its cut moves from source
time `13.29167` to Typst `13.27380`, yielding right-child q starts
`(3003270, 10336)` vs `(3002304, 10337)`. At depth 2 those differing child
curves select `0.05556` vs `0.43423`, which explains the missing depth-3
intersection. Thus the first actionable defect is the q curve arriving at the
depth-1 cut, before recursive splitting: its segment-13 start knot is
`(2985486, 10330)` in the source and `(2985608, 10331)` in Typst, while the
next knot has the same width (`10354`). This knot maps to root callback time
43, where the traced callback width is `10330` and the production Typst sample
is `10331`; the q arc x coordinate differs by 122 fixed units as well. The
curve's endpoint values therefore already diverge before de Casteljau child
propagation. A trace-only source-width correction at that one callback recovers
all 31 mass-4 recursion decisions, but is not a generic rule; applying the
separately rounded width expression globally still regresses mass 1/2 and the
raster gate. Mapping root q.x through the Typst source-time/arc table confirms
an additional geometry-clock discrepancy: at mass-4 source time 43 the source
and Typst cumulative arcs differ by `0.000656 mm`, while the largest indexed
residual is `0.061453 mm` at time 49, where the source and Typst mapped points
are `0.052807 mm` apart. Snapping the Typst points to the 16.16 grid does not
reduce the time-43 arc difference. Interval deltas concentrate at the cyclic
join: source/Typst q.x increments differ by `-0.060720`, `+0.054201`, and
`+0.019967 mm` over times 48→49, 49→50, and 50→51. At time 49, the source
circle map's exact point `(19,37) mm` matches the source knot, while Typst's
sample interpolation is `0.052807 mm` away; exact evaluation improves the
callback width from `10676` to `10674`, still one fixed unit above source
`10673`. Keep it diagnostic-only because the earlier global exact-point trial
regressed mass 2 recursion. A new source path trace records the actual mass-4
centerline cubics: the fixed-point arc lengths for segments 48 and 49 match the
source q.x increments within `0.000006 mm`, while Typst's sampled arc table
differs by `0.060720` and `0.054201 mm`. Typst's ideal-circle start also differs
from the traced source cubic start by `0.023 bp` along the tangent. This
pinpoints the remaining issue in reconstructing MetaPost's horizon arc
endpoint/angle and cyclic path-time geometry, rather than in q intersection or
source arclength integration. The next production candidate must derive those
source cubics from the input path, then pass all six coast trees and the M11
raster gate.

**M11 source offset-control replay (2026-11-04).** The pinned MetaPost 2.11
trace now includes each subdivided centerline cubic, q1 offset-template knot,
and call-indexed q2/q3 boundary controls. The independent
`diagnostics/compare_m11_offset_curves.py` replay of the upstream
`offsetPathGenerate` construction matches all 1,536 traced boundary control
points with mean error `0.0000218–0.0000282 mm` and maximum `0.0000990 mm`.
The Typst port in `_mp-offset-boundary` reproduces those controls with maximum
error `0.000099 mm`. The diagnostic then reconstructs each clipped centerline
cubic from the original M11 samples, matching traced input controls within
`0.000033 mm`; its resulting boundaries match within `0.000065 mm` and checked
lane controls within `0.000041 mm`. Passing those lanes into the production
tube renderer regresses the same-run 600 ppi M11 whole/knot RMSE from
`0.114799/0.078545` to `0.117208/0.097408`, with M4/M6 unchanged. Disabling
the new edge and shadow geometry while keeping the internal lanes still
regresses knot RMSE to `0.100047`. The source lane geometry is therefore
validated, but its conversion to Typst brush paths changes recursive call
counts and is not retained in production. The remaining concrete gap is
reproducing source callback widths and recursive q children on these exact
cubics; require source call-vector and regional raster gates before reintegrating.

**S104 source-q row probe (2026-11-04).** The first focused row, source
`y=-11.76086` / Typst row 99, has the same 19 thin-node count but only 13
source-node endpoint pairs under the generated q template. Injecting the
source root outer q template (trace serial 178) into the diagnostic replay
raises this to 17/19 endpoint pairs; 15/17 paired nodes have exact width and
arc controls, and the largest remaining q-control residual is 3 units on the
16.16 bp grid. RNG use remains 16 calls from absolute offset 74, with 8
dashes, matching the non-injected replay. The two unmatched source nodes are
the short interval from x=36.48710 to 36.51228 mm: the replay keeps that span
inside an adjacent child. A follow-up pinpoints the one-unit trigger: on
source node 32, MetaPost selects q-time `0.5` (the intersection
candidates are `0.50023` and `0.5`, with the latter nearer the target), and the
Typst source-q replay also cuts at `0.5`. Both use target width `12513/65536
bp`; the source child starts at width `12513`, while Typst's `_mp-cubic-split`
produces `12514`. This makes the candidate endpoint exceed the target and
removes the source interior crossing. The local cause is fixed-point cubic
subpath interpolation, not the q-time-to-center-path map. The source-q fixture
remains diagnostic-only; the candidate-wide gates are recorded below.

An independent MetaPost `subpath (0, 0.5)` probe now feeds the traced source
node-32 cubic directly to the native engine. Its four left-child controls
match source node 33 exactly, including the 12513-unit endpoint. The current
Typst floating conversion still yields 12514 for the injected split. The
probe is retained at `diagnostics/s104_native_subpath_probe.mp`; it confirms
the local arithmetic diagnosis but does not change the rejected all-tree and
raster results below.

The fixed-point q split was then tested as a production-wide replacement for
floating interpolation. It makes this source-q row exact (19/19 endpoint and
control matches) while retaining all 142 row call schedules, but full generated
q-tree endpoint pairs fall from 1,476 to 1,462; whole/hatch RMSE regresses from
`0.20640447/0.07183428` to `0.20640963/0.07186350`. Restricting integer
arithmetic to exact half-parameter splits raises endpoint pairs to 1,467, but
still regresses whole/hatch RMSE to `0.20640904/0.07186017`. Both candidates
were reverted. The short-row result identifies a q-subpath rounding issue,
but the correction must preserve the broader generated-q tree and raster
gates.

A narrower quantization probe traced the tie error to millimeter-to-bp
conversion noise inside `_mp-rounded`: two intended half-unit products evaluate
to `-181.5000000000001` and `-181.4999999999988` fixed units. The first rounds
to `-182`, but the second rounds to `-181`, leaving the split endpoint at
12514 instead of the source's 12513. Snapping values within `1e-7` fixed units
of a half-integer restores the injected row to 19/19 exact nodes and controls.
Across the full trace it produces 1,475/1,696 endpoint pairs and 1,235 exact
width-control nodes (baseline 1,476 and 1,213); all 142 call vectors, RNG
offsets, subdivision requests, and segment counts still match. However, the
paired 600 ppi RMSE regresses from `0.20640447/0.07183428` to
`0.20640889/0.07185927` for whole/hatch; stipple is unchanged. The global snap
was reverted. This identifies the arithmetic trigger while showing that a
global quantizer change is not a fidelity improvement.

Restricting the snap to recursive q splits, then to the q-width axis alone,
also restored the injected row's exact width controls but did not improve the
all-row gate: both variants paired 1,474/1,696 nodes with 1,234 exact
width-control nodes. Their 600 ppi whole/hatch RMSEs were respectively
`0.20640897/0.07185974` and `0.20640899/0.07185985`; both remain worse than the
retained baseline. These scoped variants were also reverted.

**S104 half-time q-knot lock probe (2026-11-05).** A narrower trial changed a
recursive q split only when its quantized time was exactly `0.5` and its
computed width missed the fixed 16.16 target by one unit. On the injected
source-q row `-11.76086`, this raises endpoint pairs `17/19 → 19/19`, exact
width-control nodes `15 → 18`, and exact arc-control nodes `15 → 17`; the
remaining q-arc error is mean/max `0.125/3` units. On the same 142-row
fixed-width-q trace, all call vectors, subdivision requests, path-segment
counts, and absolute RNG offsets still match exactly. However, full-tree
width-control matches fall from `1,213` to `1,207` of 1,476 paired nodes;
q-arc residual remains `58.733/933` units. The local oracle improvement does
not carry to the generated tree, so the source edit was reverted without a
raster trial. The row-99 tie needs the source subpath arithmetic, not a
post-split endpoint clamp. `audit_s104_q_alignment.py` now errors if the
requested node-field is absent from a trace instead of silently reporting
zero pairs.

**M11 coast callback probe (2026-11-04).** Evaluating integer source-time
callbacks at the exact cubic fullcircle points changed the mass-1/2/4 Typst
thin-node counts from `17/57/33` to `17/43/33`, against source `15/57/31`.
The trace's `.thin` summary is a different statistic. The
mass-1 exact-width count rose only `75/139 → 76/139`; mass 2 fell
`83/170 → 81/170` while its maximum fixed-width error improved `6 → 4` units.
The large tree regressions outweigh that local residual improvement, so the
candidate was reverted without a raster trial. See the detailed fixed-width
comparison in `diagnostics/README.md`.

**M11 shadow geometry performance probe (2026-11-04).** `_path-intersects-polygon`
now indexes polygon edges in a uniform grid and checks only edges in cells
overlapped by each path segment. Direct Typst comparisons against the former
full edge scan agree for 128-edge circular and rectangular polygons, including
crossings, tangencies, contained paths, and disjoint paths; the full library
entry document compiles. This accelerates the existing strand-vs-shadow
silhouette filter in `shadows-for`.

The index is now reusable through `_polygon-edge-grid`, and
`_path-polygon-crossings` returns path-segment indices, local crossing times,
edge indices, local fractions on the shadow edges, accumulated outline
parameters, and hit points. Shared-vertex hits are deduplicated. The outline
parameter is not yet a MetaPost shadow-path time; reconstructing that scale is
still required for a source-ordered callback clock.

`_path-polygon-crossings` now also accepts a uniform polygon shift while
reusing the unshifted edge grid. The focused circle/concave-outline diagnostic
returns identical ordered crossing records through both the shifted grid and
a freshly built grid. A first production integration applied it to each
shadowed lane and fed post-cut callback indices to the width law. Although the
M11 plate compiled in about 78 s, its paired 600 ppi render regressed whole
RMSE `0.12930867→0.12934565` and knot RMSE `0.07975427→0.08011008` against the
same `eae87f5` baseline. The integration was reverted. A retry must improve the
source shadow-path clock and cubic cut geometry before it can be retained.

The same edge index now serves point-in-polygon queries in tube shading. Each
shadow plane built by `strand-knot` carries its precomputed index through the
lane render, so shading samples test only polygon edges in the relevant
horizontal band and to the right of the sample. Indexed results match the
original ray-crossing rule on a 21 × 21 grid for both a 128-edge circle and a
rectangle; a crossed-tube mask-mode evaluation and the full library entry
document both complete. This preserves the current mask/shading behavior; it
supports the indexed lane-cut scan used by the callback-clock candidate.

On the full M11 plate with seed 1, Typst compile time fell from `140.888 s`
at commit `82ed62f` to `83.363 s` with the shading index. The PDFs have
identical page drawing streams and xref offsets; their differing bytes are in
the generated creation/modification timestamps and document ID. This verifies
that the acceleration preserves the complete vector plate while reducing
compile time by about 41%; it is not a source-vs-Typst raster parity result.

**M11 coast update (2026-11-04).** The table's earlier `54/52` total and
mass-1 dash deficit describe the pre-rebase renderer. The current source-origin
candidate starts merged closed outlines at the source `drawLandMass` origin,
rebases callback time and arc positions, and includes its closing interval.
Its six visible-mass brush-call totals now match source exactly
(`12/30/6/2/2/2`, aggregate 54). Source q-knot counts now match on all six
visible masses: a follow-up removed the extra geographic closing edge before
horizon clipping, matching mass 2's source path length 169 and reducing its
fixed-width residual from max 814 to 6 units (83/170 widths exact). Mass 2's
recursive thin-node count is 57/57 source/Typst; masses 1 and 4 remain 15/17
and 31/33. The seam q-time still differs, and the paired raster gate remains
outstanding; details are in
[the coast trace audit](../diagnostics/README.md#m11-coast-cyclic-origin-correction).
A follow-up preserved the global arc sample count while snapping the nearest
sample to each exact fullcircle cubic boundary. Brush-call totals and outline
sample counts stayed fixed, but thin-node counts changed from `17/57/33` to
`15/41/33` for masses 1/2/4 (source `15/57/31`); the mass-2 tree worsened, so
the production candidate was reverted. Exact cubic boundaries alone do not
explain the mass-specific q segmentation.
For fully visible closed masses 5/7/8, the source root paths have lengths
`38/13/5` and q-knot counts `39/14/6`, with the last two q knots repeating
the start. Preserving the Typst run's explicit endpoint and counting its
cyclic terminal path-time now matches those q counts; all 59 paired fixed
widths are within one 16.16 unit, and source/Typst thin-node and RNG-draw
counts match. The M11 PDF compiles, but paired raster validation remains
pending because the Nix and Guix daemons are unreachable in this environment.

These are evidence-backed investigations, not claims that all seven can be
made raster improvements. The first two have the strongest bounded replay
oracles; continue with the smallest isolated case, preserve paired baseline
metrics, and record a rejected candidate when the production gate fails.

### M11 coast root-time audit

A fresh pairing of source root q knot zero against the production Typst outline
maps masses 1, 2 and 4 to outline index 1 at path time 1, with position errors
`0.000137/0.000117/0.000073 mm`. Masses 5, 7 and 8 map to index 0 at time 0,
with errors no greater than `0.000164 mm`. The source root width equals the
Typst width sample at index 1 for masses 1 and 4, and differs by one 16.16 unit
for mass 2. This confirms a path-time origin mismatch whose source start
depends on the assembled visible contour; rotating to the geographic input's
first projected point is not valid.

Two diagnostic fixes were rejected before rendering. Rotating each outline to
the first geographic point increased mass 1's call count from 10 to 16.
Changing the arc table from its current sentinel convention to one entry per
outline point preserved mass 1's tree but changed Typst node counts from
`56→34` on mass 2 and `34→10` on mass 4, against source counts 57 and 31.
Both experiments were reverted. The next probe must reproduce the source
`drawLandMass` result-path start and carry that origin through both q width and
arc coordinates before changing coast recursion.

A follow-up source-oriented cyclic shift starts at the visible coast vertex
after an explicit horizon intersection and aligns the arc table with the
rotated points. This puts source q knot zero at Typst time zero for masses 1,
2 and 4. On mass 4 it reproduces the source root cut at `14.29183 mm` (source
`14.292 mm`). However, its complete recursive tree is worse: mass 1 calls rise
`10→12`, mass 2 has 58 nodes versus 57 source, and mass 4 falls to 8 nodes
versus 31 source. The candidate was reverted without a render.

The source's first mass-4 child reports q time `31` and then `LEAFNODE`; the
shifted Typst replay maps the endpoint to parent time `30.239578` and rejects
the cut. Those are matching leaf decisions, so this endpoint is not the tree
mismatch. The next source child cuts at q time `13.29167` and recurses, while
Typst cuts at `13.27380`. The source then recurses at the next level's second
child, cutting at `0.05556`; Typst finds `0.43427`, the first large parameter
divergence. The recursive-tree gap is therefore downstream of the matching
endpoint leaf.

The root q knot audit also shows why matching the first cut was insufficient.
Mass 4 has 52 source and Typst q knots; the fixed y-width differences are at
most 3 units, but cumulative x/arc differences reach 11,416 fixed units at
knot 49, then 1,347 and 1,703 units at the final two knots. The next probe
must trace source and Typst arc positions through the closing horizon arc,
then pair q knots in the recursive second child before modifying production
recursion.

The latest M11 callback-time integration attempt used sampled lane/shadow
polygon intersections inside `_tube-layout`; despite bounding-box rejection,
the 600 ppi M11 run produced no PDF within 85 seconds. That production edit was
removed without image claims. Keep the inverse path-time map, but compute
shadow intersections with a spatial index or shared source-order events before
retrying the renderer integration.

The initial 2026-11-04 closed-endpoint probe restored the third repeated
mass-1 q knot, but added a root sample on masses 1 and 2; that version was
reverted. A refined candidate preserves the endpoint and uses the resulting
`path-time` as the cyclic `source-time-end`, removing the synthetic extra
cycle interval. Mass 1 then returns to 139 root q samples and monotone
`(arc,width)` alignment improves from 135/139 to 136/139. Its depth-1 right
cut moves from `22.71739` to `23.71739`, within `0.00187` of source `23.71552`.
The root, depth-1, depth-2, and depth-3 q-segment counts now match the source
through `138`, `98/41`, `24/18`, and `1/24/8/11`; thin-node counts and brush
calls stay unchanged on M1/M2/M4. Mass 2 retains its existing one-sample excess
(`171` versus `170`). Keep the source-level correction; its paired 600 ppi
raster gate remains outstanding because the current shell lacks MetaPost and
Ghostscript.

The refined mass-1 trace's next count difference occurs after the depth-3
right parent: the source cut is `9.00267` and produces depth-4 q segments
`10/2`, while Typst cuts at `9.0` and produces `9/2`. The next probe should
compare this parent's q controls and both ray-hit parameters, then run the
paired crop gate when the renderer toolchain is available.
That comparison is now isolated to source q curve 9's endpoint controls:
source y controls are `9796/9608/9421/9233`, Typst `9793/9607/9420/9234`,
with target `9793`. A four-way replay selects local q time `0.00267029` from
the source curve with either ray, but `0` from the Typst curve with either
ray. The remaining cut-time difference is therefore in q-knot/control
generation at this boundary. Pair its source callback path time and arc before
adjusting width arithmetic; then rerun the paired crop gate.

The sequential q-control audit applies the source-to-page vertical flip and
pairs recursive nodes by center-path endpoints. On row `-6.37912`, all 19
source/Typst nodes pair; every width q control is identical, and the maximum
accumulated-arc q-control error is 17 fixed units. Across all rows, 1,475/1,696
source nodes pair within 0.005 mm and 1,209 paired nodes have exact width
controls; the unpaired nodes remain concentrated in rows with differing tree
geometry. See the reproducible procedure in `diagnostics/README.md`.

The first full-sequence q trace incorrectly advanced later rows with the
baseline brush's RNG use. That produced invalid all-row call statistics and is
superseded: after giving the q candidate its own subdivision and brush cursor,
all 142 rows match source calls, subdivision requests, path segment counts,
and absolute random-draw positions. Integrating that source-fixed width q into
`flat-surface` improves both S104 whole-frame and hatch RMSE in a same-run
600 ppi source comparison. The updated implementation is retained; the
remaining S104 differences include a small ink-coverage increase and local
q-arc/geometry errors.

The S104 `rng: "metapost"` hatch now evaluates every `pathSubdivide` point
with MetaPost's 16.16 linear interpolation before constructing q curves. This
retains all `142/142` call, subdivision, path-segment, and absolute RNG-offset
matches. The focused first-mismatch row improves from `10.932/17` to
`10.780/16` mean/max q-arc residual units; across the full trace, paired
nodes improve `1475 → 1476`, exact width-control nodes `1209 → 1213`, and mean
arc residual `59.525 → 58.733` (maximum remains 933 on rows with divergent
trees). Its paired 600 ppi whole/hatch RMSE improves
`0.20640646/0.07184556 → 0.20640447/0.07183428`, with stipple unchanged.
Rounding cumulative segment lengths in the same candidate worsened its
focused q residual and image score, so that part was discarded. The retained
change is the source-faithful point interpolation; the residual q arc mapping
still requires source-order centerline state across recursive children.

### Accepted wood width-template alignment

The source-field `contour-brush: "cell-range"` path now passes explicit
source-rounded 16.16 widths at each reversed contour path-time knot into
`stroke-ink`. This reproduces the source `offsetPathTemplate`'s discrete width
samples while retaining the existing center path, traversal and RNG stream.
The paired 600 ppi comparison used the same pinned source, fixtures and
renderer: the baseline `fiziko.typ` SHA-256 was
`ba1c65ce0cc802cc8407725a982f0553c7de33fd2256ce968814ee2766ec65dc`, and the
candidate was `419b84ed90e7893f8d683e2712ab32d2686c6be833e141e455b261eb8f64acb3`.
M9 whole-frame RMSE improves `0.21156032 → 0.21138154`; three of four panel
crops improve, while top-right regresses `0.23363340 → 0.23368409`. M9 ink
coverage moves slightly farther below the source, `3.7120% → 3.7069%` versus
`4.2032%`. S105 whole-frame RMSE changes `0.10213793 → 0.10214082`, with its
block crop unchanged and surface crop slightly worse (`0.07693635 →
0.07694344`). Retain the source-semantic change as a small net image improvement
with those tradeoffs recorded. The first-contour diagnostic also improves:
Typst outer nodes move `7 → 41` against 37 source nodes; thin nodes move
`48 → 50` against 65; parent-paired recurse/stop decisions improve from
`37/42` to `40/44`, with close endpoint pairs (`<0.1 mm`) moving `36 → 37`.
The aggregate first-contour dash/RNG totals remain an exact `12/24` match.
Later branch geometry, other contour calls and their random-call ordering
remain open.

### Fixed-point q-width span decision

When `_ink-loops` carries a source q template, its thin-recursion gate now
compares the width span and step as 16.16 integers. This avoids converting
fixed q values to millimetres and losing an equality at the branch boundary:
the S104 row-93 child has a 544-unit span and a 544-unit step, so source
recursion continues. M9 whole RMSE changes `0.21138154 → 0.21138138` and
S105 changes `0.10214082 → 0.10214180` (block unchanged; surface
`0.07694344 → 0.07694583`). All five M11 regions are pixel-identical to the
committed baseline. Keep the source-exact integer decision with these
negligible raster tradeoffs recorded. The separate S104 production q-knot
injection remains reverted because its full-page image gate regressed.

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

- [x] **Thin-brush entry width guard.** The pinned upstream
  [`thinBrushGenerate`](https://github.com/jemmybutton/fiziko/blob/54a63dba8e6700a5e70d3508838edebcbf0f45fe/fiziko.mp#L445-L487)
  only searches for a cut when the upper width corner exceeds
  `minWidth + 0.01 bp`. `_ink-loops` now applies the equivalent strict
  `hi > dash-floor` condition before thin recursion. On the exact M11 knot-strand
  q replay,
  this resolves both formerly extra splits and produces exact source trees and
  q controls on all three traced lanes (40/40, 20/20, 30/30 nodes); random-call
  totals now match 16/16, 6/6 and 14/14. Same-checkout 600 ppi comparisons of
  M4, M6, M11, M9 and S104 are pixel-identical to the no-guard baseline, so
  this is a source-recursion correction with no measured raster change on
  those plates.

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
  A mask-shape trial replaced the knot's white thick-centerline erasure with a
  polygon sampled from centerline normals and radius. Same-run 600 ppi M11
  whole-plate RMSE worsened `0.112899 → 0.113991` and knot crop RMSE
  `0.058230 → 0.069732`; the candidate was reverted. The source silhouette is
  built from `offsetPathGenerate` boundaries, so normal-offset samples do not
  preserve its joins and end geometry.
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
  Replacing the thin recursion's raw floating `step` gate with the already
  source-rounded `thin-step` is behaviorally inert on the current evidence:
  canonical recursion traces for all 18 source post-shadow lane inputs are
  byte-identical, and the 142-row S104 trace is also byte-identical. The
  candidate was reverted; this rules out that gate's final scalar rounding as
  the cause of the three M11 call-vector mismatches.
  The source trace now stores raw 16.16 cut parameters. A dedicated analyzer
  verifies 18 parent/left-child and 18 parent/right-child two-dimensional q
  curves exactly using fixed-point de Casteljau subdivision with nearest-unit
  rounding. Reuse and recursively split those source q controls in the replay
  before changing production recursion. Typst now implements this 16.16
  subdivision primitive, and a paired replay matches all 18 left and 18 right
  child control arrays exactly after quantization. The primitive is not yet
  wired into `_ink-loops`, so no renderer change is claimed.
  A fixed-width evaluator reconstructed the q width segment from its two
  16.16 callback endpoints and evaluated it by fixed-point de Casteljau. All
  76 traced call-4/lane-2 q cubics across the six recursive levels have
  control points exactly equal to the nearest-unit linear controls derived
  from their endpoints. The evaluator left the 15/18 lane call match unchanged
  and added 10 recursion nodes across the three divergent lane traces, including
  a spurious `9.25e-6 mm` endpoint branch; it was reverted. The source width
  curve within each callback interval is already linear, so the remaining
  mismatch is the q path's recursive subpath/time remapping, not missing
  curvature between callback endpoints.
  A full diagnostic `_ink-loops` prototype then carried fixed-point q cubics
  and source-time interval maps through both outer and thin recursion, splitting
  each q path with de Casteljau alongside the sampled center path. It still
  matched only 15/18 lane call totals. On the three divergent lanes, outer
  nodes grew from baseline `5/7/5` to `39/39/39`; thin nodes were
  `76/20/70` versus baseline `34/20/32`. The first root cut was about
  `0.00004` source-time units from the source cut, then a near-endpoint q
  crossing repeatedly split the child. This prototype used fixed-point
  bisection for q crossings, so the result narrows the remaining gap to source
  intersection selection and its mapping onto the center samples; the q-state
  plumbing was reverted without a raster trial.
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
  x `35.07321`). At that point this isolated the mismatch to low-level
  `intersectiontimes` behavior and Typst's recursive subpath parameterization;
  the source-side solver is now reproduced, while the production Typst port
  and recursive subpath parameterization remain open.
  The integer 16.16 packet-search replay initially matched 67/76 raw pairs
  because it passed one tolerance to all four child-pair visits. MetaPost's
  `NOT_FOUND` traversal accumulates `three_l` as it switches to right packets:
  left-left uses the split tolerance, both mixed pairs use one increment, and
  right-right uses two. Encoding this branch-dependent tolerance makes the
  replay exact across the fresh 62-row trace: 6,784/6,784 direct/reverse raw
  hit pairs and all 1,696 wrapper cut decisions, including every endpoint and
  interior case. It also reproduces all 17 widths in the minimized M11 coast
  endpoint sweep. Guard depths 15–23
  and four tested half-rounding rules all retain 76/76 on the focused S104 row;
  the old 31/76 guard-order result came from the incomplete tolerance model and
  is superseded. This identifies a concrete source-semantic gap and removes
  the low-level intersection uncertainty. A standalone Typst implementation
  in `intersection.typ` now matches the S104 node-172 direct/reverse pairs
  (4/4) and all 17 M11 endpoint levels within one fixed-point unit. A
  sampled-frame `split-path` integration trial lowered row-93 Typst nodes from
  24 to 16 but moved farther from the source's 40 decisions and 5 dash leaves;
  it was reverted. Keep the helper diagnostic-only until the exact source
  width-template cubics and recursive parameter mapping are carried through
  child paths, then compare complete S104 and M11 trees and rasters.
  A thin-only prototype then rebuilt straight 16.16 q cubics from each
  recursive node's sampled widths and routed those cuts through the fixed
  intersection solver. On row 93, its formerly divergent cut moved from
  `x=44.89566` to `x=39.54028 mm`, within `0.0013 mm` of source `39.539 mm`.
  The full 142-row trace did not improve: source/baseline/prototype dash leaves
  total `687/699/699`; summed per-row absolute dash-count error changed
  `166 → 168`, with 1 row better, 139 tied and 2 worse. Thin-node count rose
  `1613 → 1843` against source `1696`. Rebuilding q from each sampled child
  recovers this local hit but loses source q state across recursion, so the
  production prototype was removed. Preserve the cut as a local oracle; the
  next integration must carry and split q controls with the child paths.
  A follow-up carried each straight 16.16 q cubic through recursive de
  Casteljau splits alongside its center path, storing q state as a flat integer
  sequence to fit Typst's collection typing. It reproduces the row-93 depth-4
  source cut at `x=39.53914 mm`, but the full 142-row trace does not improve
  the aggregate dash tree: source/baseline/candidate dash leaves are
  `687/699/697`, and per-row absolute dash-count error stays `166` (2 rows
  better, 139 tied, 1 worse). Thin nodes rise from `1613` to `2615` against
  source `1696`; outer nodes are `1004` against source `1340`. No raster trial
  was warranted. The candidate was removed. The remaining mismatch is
  downstream of that matched cut: recursive q-time and center-path subpath
  mapping still diverge on child branches.
  Rebased each split child's q x controls to start at zero, as a source
  `subpath` does. The full 142-row trace's ordered recursion decisions, dash
  flags, cut parameters and cut points are identical to the carried-state
  candidate (canonical trace SHA-256 `082f2a75addf435ce880d5975c77140da4cc257aa1db767f271edba8c4c3f689`);
  aggregate counts remain `1004` outer nodes, `2615` thin nodes and `697`
  dashes. A mere x-origin reset is translation-invariant in the intersection
  search and cannot explain the child-tree divergence. This no-effect probe
  was removed without a raster trial.
  The recursive 2D q-state prototype developed for M11 was also replayed on
  S104 row `-15.3487` (Typst row 103), using the row's five rounded width
  samples. It grows the outer tree from 5 nodes to 23, close to the source's 21,
  while preserving the same 5 thin nodes and 6 RNG calls as baseline. However,
  it selects the opposite root crossing (`2.34457` versus source `1.65523`),
  then recovers a near-source cut only in the child (`1.65501`). An explicit
  left/right tie-preference switch leaves that trace unchanged, so this is not
  a tie-policy-only issue. The probe was removed from the S104 diagnostic; do
  not generalize the M11 q reconstruction to S104 without source q controls and
  local-time mapping. This isolates source q geometry/parameterization as
  necessary even when node totals move closer.
  A separate boundary probe changed the thin-recursion span test from raw
  floating subtraction to a 16.16-rounded width span. Using the already
  rounded `thin-step` alone leaves all 142 row traces identical; rounding the
  span adds four thin nodes (`1613 → 1617`) but worsens the paired per-row
  thin-node error (`429 → 433`) while leaving dash counts unchanged. The
  threshold candidate was reverted. The source-equal one-step boundary still
  needs to be tested together with the carried q-template branch where it
  occurs, rather than applied as a global width-span adjustment.
  A thin-only q-state replay then applied that one-step comparison in 16.16
  integers. On row 93 it reproduces the source branch through nodes 172–175:
  cuts land at `x=39.53897`, `36.69320`, `35.27024`, and `38.11617 mm` versus
  source `39.53911`, `36.69320`, `35.27024`, and `38.11617 mm`; the row tree
  reaches all 19 thin nodes and 5 dash leaves, matching source. Across 142
  rows, however, it creates 2749 thin nodes (source 1696, baseline 1613), and
  per-row thin-node/dash error rises from `429/166` to `1429/168`. This local
  exact match does not justify production use; the remaining mismatch is the
  initial q-template and child-curve topology across rows, not this branch's
  threshold comparison. The diagnostic implementation was removed before
  raster rendering.
  The replay is documented in `diagnostics/README.md` and implemented by
  `diagnostics/replay_s104_thin_intersections.py`.
  A full sequential-cursor integration was then evaluated: the q-state
  candidate consumed its own subdivision and brush draws before processing the
  next row. It regressed against the baseline on the 142 paired source rows:
  requested-subdivision mismatches rose `54 → 63`, per-row brush-call L1 error
  rose `332 → 630`, and exact brush-call rows fell `108 → 83`. At source row
  `y=-6.37912`, the candidate consumed 14 brush calls versus 10 in MetaPost
  (the baseline consumed 6); the candidate's earlier cursor drift had already
  changed the subdivision request at row 45, while the baseline first diverged
  at row 53. Total candidate brush calls were 880 versus 1,374 in the paired
  source rows. The sequential q-state integration was reverted without a
  raster trial; the fixed-point solver remains a local oracle, and the next
  useful step is to preserve the original source width-template and its time
  mapping, rather than reconstructing straight q cubics from sampled widths.
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
  A local candidate rounded each intermediate operation in the wood width
  formula to MetaPost's 16.16 grid. The M9 diagnostic outer-node count moved
  `7 → 9` (source 37), while thin nodes, dash leaves and RNG calls stayed
  `48/12/24`; call 10 retained the same wrong recurse decision. Same-checkout
  600 ppi full RMSE regressed slightly on M9 (`0.21156032 → 0.21157157`) and
  S105 (`0.10213793 → 0.10215037`). Ink coverage moved closer on both; S105
  surface crop improved `0.07693635 → 0.07692555`, but block crop regressed
  `0.12790793 → 0.12793839`. Since the brush tree and call-10 mismatch did not
  improve and whole-plate error rose on both plates, revert this arithmetic
  candidate; do not infer source parity from operation-by-operation rounding
  alone.
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
  Brush recursion remains open. A fresh 2026-11-04 trace of the current
  checkout supersedes the earlier counts: Typst has 41 outer/52 thin nodes
  versus 37/65 source, while dash leaves and RNG calls both match at 12/24.
  The independently replayed source path matches all 22 vertices and 19 cells
  within `0.000718 mm`; root length is 17.2651 mm versus 17.2808 mm source.
  Parent-aware thin pairing is 44 nodes, 37 within 0.1 mm, with 39/44
  recurse/stop decisions. The trace refresh itself does not imply changed
  raster output; the separate controlled candidate gate is recorded below.
  Rounding generated q-knot arc coordinates to the MetaPost 16.16 grid leaves
  this tree unchanged and produces pixel-identical S105/M11 renders, but M9
  RMSE regresses `0.21138138 → 0.21152740` on paired 600 ppi runs; the edit was
  reverted. Endpoint quantization alone is therefore not the missing wood
  recursion state. Continue tracing the mapped source q time and recursive
  path geometry, rather than changing global cut thresholds.
  A new opt-in M9 q replay now generates x knots from forward cLine arc length
  while retaining the reversed brush's callback-width sequence. Its first
  thin-call q controls match all 14 source cubics within `0.0063 mm` in x and
  `0.000097 mm` in width; tree pairing improves to 46 nodes (all within
  0.1 mm) and 43/46 matching decisions. A production full-contour brush with
  rectangular clipping nevertheless regresses M9 RMSE `0.21138138 →
  0.21201468` across all four crops, so that renderer branch was reverted.
  S105/M11 are pixel-identical. Keep the q replay as evidence and resolve how
  to carry its time map across the existing clipped-path production topology.
  Brush recursion remains open (current 41 outer/52 thin versus 37/65 source),
  and only the full diagnostic contour currently has the complete source-time
  state mapping.
  The q replay localizes its three remaining thin-branch decision mismatches
  to source calls 10, 17, and 18. Their paired endpoints differ by only
  `0.00323`, `0.00209`, and `0.00235 mm`. Calls 10 and 17 are source dash
  leaves but Typst splits them; call 18 is a source split but a Typst dash
  leaf. The source width levels sit on the 16.16 threshold grid (for example,
  call 10 has source `w2 = 0.04979 mm`, while the paired Typst width range is
  `0.0497870–0.0556383 mm`). This makes the next bounded check the exact source
  width/threshold arithmetic at those three recursive nodes, including the
  callback's cell-corner values. Do not change global thresholds: all 46 q
  nodes already pair within `0.1 mm`, and the full-contour raster candidate
  regressed.
  The current paired fixed-point audit now reports source/Typst q-width ranges
  directly: call 10 `[9248,10335]/[9249,10336]`, call 17
  `[8159,8704]/[8161,8705]`, and call 18 `[8704,9250]/[8705,9248]`. Thus call
  18's Typst width span is 543 units, below the 544-unit source recursion
  step, while the source span is 546. For call 17, the selected source q cut
  is `0.00368` and is rejected by the source `t > 0.01` guard; the paired
  Typst cut is `0.01843` and passes. The difference is therefore in the
  callback q-width controls at 1–2 fixed units and their cut location, not
  only the boolean width-span test. Continue with source cell-corner and
  fixed-point callback evaluation; retain the source controls as the oracle.
  Typst thin-node traces now include endpoint widths: at paired call 10 they
  match the source endpoints in reversed spatial order within
  `0.000018/0.000014 mm`. This rules out a wholesale orientation error there;
  the level-9/10 disagreement is sensitive to local cell-range values.
  Compare the source and Typst cell-corner samples before considering a local
  correction; the global level bias remains reverted.
  `CLVFIX` now captures exact 16.16 source values for the first 72 lattice
  samples. The corrected comparison now removes Typst's 24x contour scale and
  compares both fields with their shared column jitter intact; current same-run
  mean/max absolute errors are `1.29e-5/6.66e-5`. The earlier checker removed
  `CLCOL` only from the source side, overstating errors by the column offset.
  Source cell `(3,16)` has range `0.033203125`
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
  The old source call total `27` was an instrumentation undercount: its regex
  missed the implicit-multiplication call `1/2uniformdeviate(d1)`. After
  wrapping that call, source/Typst totals are `54/52`; masses 2/4/5/7/8 match,
  while mass 1 has one extra source dash (two calls). The current q-template
  trace has 106/80 visible source/Typst recursion nodes, with 76 paired nodes,
  69 matching recurse/stop decisions, and 66 pairs within 0.1 mm. Mass 2's
  first paired divergence is at depth 5:
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
  Fiziko selects the forward pair. The integer packet replay originally
  predicted `(0.999996, 0.999996)`, missing the source result, because it passed
  one tolerance to all child pairs. MetaPost's `NOT_FOUND` traversal adds
  `three_l` when switching to a right packet: left-left uses the split
  tolerance, both mixed pairs use one increment, and right-right accumulates
  two. With this branch-dependent tolerance, the replay exactly reproduces
  the minimized M11 result and all 17 levels in its endpoint sweep. It also
  matches all 6,784 raw direct/reverse hit pairs and all 1,696 wrapper cut
  decisions from the fresh 62-row S104 trace; guard depth 15–23 and four
  half-rounding variants leave the focused result at 76/76. Earlier 67/76 and
  31/76 guard experiments used the incomplete tolerance model and are
  superseded. The source-side intersection algorithm is now reproduced; the
  remaining M11 coast gap is integrating it with
  Typst's piecewise width/path representation and comparing the full recursion
  tree and raster. The exact input audit checks 132 cubic controls, 76 ray
  endpoints and 38 raw-hit pairs against their decimal companions (maximum
  differences `7.28e-6`, `6.59e-6` and `6.81e-6`).
  The endpoint behavior is reproduced independently of coast traversal. The
  remaining implementation gap is matching this fixed-point cubic
  intersection behavior in the Typst brush model. A fresh comparison of the
  first mass-1 divergence narrows the same gap from the other endpoint: both
  implementations have the same width range and almost the same path
  endpoints (0.00870 mm mean endpoint error), but MetaPost finds a cut at
  source path time 0.18750 and creates a 0.203 mm child while Typst finds no
  crossing. The requested width equals the node's starting width in both
  traces (`0.04979014 mm`); the source's traced width-template cubic still
  yields an interior hit. This rules out a width-endpoint mismatch as the
  cause and points to the cubic width-template/first-hit representation at
  equality. It does not justify accepting arbitrary endpoint hits: the
  production fixed-point-intersection trial changed tree pairing and slightly
  regressed the 600 ppi whole-plate RMSE (`0.11289878 → 0.11291172`), so it
  remains reverted. The next probe should replay this exact mass-1 node's
  width-template controls and selected hit before attempting another
  production integration. That replay is now in
  `diagnostics/metapost_intersection_sweep.typ`: with the exact traced cubic
  and ray controls, the Typst fixed-point solver returns the source-selected
  hit `(0.98898315, 0.1875)` exactly (direct raw pair `(1, 0)`, reverse raw
  pair `(0.98898315, 0.8125)`). The intersection algorithm is therefore not
  the remaining cause for this node; production still needs to preserve or
  reconstruct the source's cubic width-template through recursive children.
  A production prototype then rebuilt straight 16.16 q cubics from Typst's
  sampled widths and routed all coast cuts through this solver. It still
  missed the mass-1 start-width cut, grew the visible Typst tree from 48 to 64
  nodes, and moved mass 2's first paired divergence from depth 5 to depth 3.
  The paired decision score changed only from 37/46 to 44/54, so this
  representation did not resolve the traced source controls and the prototype
  was reverted before raster rendering.
  A separate source-time width-grid trial sampled the analytic coast width
  callback at integer source times and rebuilt straight fixed-point q cubics.
  It produced 15/11 nodes for source/Typst on mass 1 (9/11 paired decisions,
  0.372 mm root error) and 57/97 on mass 2 (29/35 paired decisions,
  0.168 mm root error). This does not establish a closer recursive state, so
  no full-render trial was warranted and the production hook was removed. The
  next candidate must carry the source q cubics and their recursive path-time
  maps, rather than infer them from callback samples.
  The exact cubic replay remains diagnostic; the next implementation needs to
  preserve the source q path as recursive state instead of rebuilding it from
  each sampled child. A q-knot pairing against the original Typst coast
  samples narrows the geometry contribution: 23 of 25 source knots on the
  first mass-1 depth-2 node match Typst samples within 0.001 mm. Those matched
  knots have mean/max position error `0.000111/0.000228 mm` and width error
  `0.00000303/0.00000550 mm`. The two unmatched points are the recursive
  child's generated endpoints (nearest input-sample errors 1.082/0.434 mm),
  not widespread projection or callback drift. This points the next work at
  preserving the cut endpoints and q subpath parameter through recursion.
  The comparator now reports signed source-minus-Typst q.x deltas against
  matched sample arcs. At M1 depth 2, 23 matched knots average `-0.37381 mm`
  with at most `0.00034 mm` deviation; at M2 depth 2, 56 matched knots average
  `-0.16806 mm` with at most `0.00064 mm` deviation. Their position/width
  errors stay below `0.00053/0.0000063 mm`. These nearly constant offsets are
  consistent with different closed-path arc origins, not accumulating length
  error; a uniform q.x translation cannot change the midpoint intersection.
  M2 depth 1 has a wider `0.02264 mm` maximum deviation, so the origin
  explanation is not assumed for that node. The remaining actionable gap is
  mapping each q cut time to the recursive centerline child.
  The source trace also contains three identical consecutive q knots at one
  M1 contour location (path times 108–110). Typst had collapsed the repeated
  centerline vertex while advancing its source-time label from 108 to 110;
  interpolation at time 109 then invented a segment. Preserving repeated
  vertices within a coast run restores all three times. This changes only M1
  (155→156 input points); all per-mass brush calls and thin-node counts remain
  unchanged, while the first paired node endpoint error falls
  `0.02247→0.00870 mm` and its starting width now equals the source threshold.
  The same-checkout 600 ppi comparison is effectively unchanged: whole/globe
  RMSE moves `0.11289878/0.18989608 → 0.11289888/0.18989648`; other M11 crops
  are pixel-identical. Retain this source-path-time correction; it does not
  yet resolve the recursion decision. Repeating the integer-time q-grid trial
  after preserving this vertex leaves M1/M2 trees unchanged at 11/97 Typst
  nodes (source 15/57), with the M1 depth-2 candidate q array still one knot
  short. The q-grid hook remains rejected; the source q subpath is not
  recovered from integer-time width samples alone.
  The source closed-path seam was checked separately: its first point maps to
  Typst outline index 1 for masses 1, 2, and 4, and index 0 for masses 5, 7,
  and 8, all within 0.00014 mm. The first three outlines start at the horizon
  crossing. Rotating those paths to index 1 leaves all six Typst recursion
  trees, widths, RNG call counts, and the 600 ppi M11 metrics unchanged, so the
  candidate was reverted. The remaining gap is recursive q-template state,
  not the closed path's cyclic starting index.
  A follow-up rotated both the outline and its path-time labels to the first
  projected input coordinate. That coordinate is not the traced source
  `drawLandMass` seam: the M1 source start maps to outline index 1, while the
  projected input start maps to a different visible run. The candidate moved
  M1 coast calls from 10 to 16 (source: 27 across all visible masses) and its
  root thin cut from path time 98.70260 to 44.48785; other visible-mass call
  counts were unchanged. It was reverted without a render trial. Future
  parameter rebasing must use the traced source seam, not assume the first
  input coordinate is the contour origin.
  Rotating instead to the traced seam at outline index 1 and rebasing its
  source-time labels moves M1's root thin cut to 97.70260, within 0.0033 of
  source 97.69934. However, M1 calls rise from 10 to 12 (source: 6), while
  M2/M4 call counts stay at 30/6 (source: 15/3). Without paired-tree or raster
  improvement, this phase candidate was reverted too; keep the measured root
  time as a clue for carrying the recursive q template, not as a production
  change.
  A new source-side audit captures exact 16.16 q knots, cut times, and the
  selected q cubic controls. Fixed-point de Casteljau replay matches the full
  child q-knot sequences, not only their endpoints, for all 7 mass-1 and 28
  mass-2 recursive cuts; endpoint error is zero 16.16 units. This confirms
  MetaPost preserves the sliced q state through recursion; the missing
  behavior is carrying that state alongside Typst's recursive center path.
  The audit is diagnostic and does not change production rendering. A new
  source-width-fixed replay injects the traced 2D q cubics, carries their
  source path-time maps through Typst recursion, and uses the exact
  `intersection-times` solver. A fresh replay of the same trace now matches
  all 18/18 lane call totals and exact thin-node trees on the three formerly
  divergent lanes: call 4/lane 2 has 40/40 nodes, call 4/lane 6 has 20/20,
  and call 5/lane 2 has 30/30. `compare_m11_thin_trees.py` also confirms every
  replay q-control array equals its corresponding source control array. This
  closes the recursive consumer once its q-state is supplied, but the source
  q controls are still injected from trace fixtures; generic q-template
  generation after `shadowCut` and production integration remain open. The
  exact fixture replay is a bounded oracle, not yet a production correction.
  Earlier q-state replays without the full source controls showed branch
  differences on these lanes; those are superseded by this exact-state replay.
  The first historical call-4/lane-6 tree divergence was localized: on a
  5.913 mm branch the source continues splitting around a width maximum of
  `0.19926 bp`, while the replay's reconstructed q cubic peaks at
  `0.07029610 mm`, only `0.00000538 mm` above its `0.07029071 mm` threshold,
  and its intersection query returns no cut. The source trace contains eight
  repeated node pairs at this near-threshold boundary. This supports a
  fixed-point endpoint/control comparison and source hit-selection audit at
  that branch; it does not support a broad tolerance adjustment.
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
   For M11 knot-strand recursion, the fresh MetaPost trace now exports the exact
   outer q cubics for calls 4/lane 2, 4/lane 6 and 5/lane 2. Feeding those
   controls into the isolated Typst replay matches source outer-node counts
   on all three lanes and all 18 source random-call totals. Lane 4/6 also
   matches its thin-node count exactly (20); before the thin-entry guard,
   lanes 4/2 and 5/2 had two extra Typst thin nodes each (42 vs 40 and 32 vs
   30). The replay q controls exactly match source controls at the first
   divergent nodes, ruling out curve geometry as the cause. The source gate
   `w0 > minWidth + 1/100` explains both stops; applying it makes all three
   thin trees and their random-call totals exact. The source q controls remain
   trace fixtures; the production guard leaves the five measured renders
   pixel-identical. The new `diagnostics/compare_m11_thin_trees.py` pins the
   former first decisions: on 4/2,
   source stops at depth 1, while replay cuts at path time 6.77946 and creates
   a 0.02238 mm child; on 5/2, the first 29 decisions agree, then replay cuts
   the final source leaf at 0.04147 and creates a 0.01092 mm child. Both source
   nodes have endpoint widths 0.02344/0.01866 mm and no source cut record.
   Lane 4/6 had an exact 20-node tree already. The two removed splits sat near
   the 0.023432 mm width floor. The replay
   now records each thin q cubic in source 16.16 units; those controls exactly
   equal the source at both former first-divergence nodes. All source q paths
   match replay on 4/6 and 5/2, and all controls match through the 4/2 tree.
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

**M11 coast q.x follow-up (2026-11-04).** A source-time-aligned root-knot
comparison finds mass-1/2/4 q.x mean absolute errors of
`0.00391/0.02388/0.88434 mm`. Adding the sewn coast-to-horizon connector length
at each arc start only changes them to `0.00390/0.03607/0.88404 mm`; the same
candidate reduces mass 4's Typst thin tree from 33 to 9 against 31 source
nodes. It was reverted. The geometry trace still needs direct matching of
MetaPost's cubic subpath arclength and cyclic endpoint ordering; a straight
connector correction alone is not sufficient.

**M11 mass-4 source origin (2026-11-04).** A fresh `M11COAST` trace confirms
that the first input point is hidden and the source path starts at the first
visible vertex. The Typst outline previously began at the preceding horizon
entry point, one path-time early. Rotating this single-run hidden-start outline
aligns the source start to Typst point 0 within `0.000058 mm` and reduces
mass-4 root q.x mean absolute error `0.88434→0.00182 mm`. Source and Typst
both retain 6 root calls and 3 dashes. The 600 ppi pair has effectively unchanged
whole/globe RMSE (`0.114784047/0.189281541→0.114782776/0.189276409`), with other
component metrics unchanged. Keep the origin mapping; recursive mass-4
decisions remain worse (`31/7` thin nodes), with the first child cut at source
q time `0.05556` versus Typst `0.43423`. The next target is fixed-point q
subpath propagation after the matching root cut (`30.23958`).

The source/Typst child q-control comparison now pinpoints why that hit changes:
source starts the first q cubic at x `45.82626 bp`, width fixed `10336`, exactly
at its left-ray x bound and one unit below ray height `10337`; Typst starts at
x `45.81152 bp`, width `10337`. Its endpoint lies outside the ray's x range,
so the source's first interior crossing disappears. Reconstruct the fractional
q.x/width at the recursive boundary before changing intersection tolerances.

**M11 coast cubic-time inversion (2026-11-05).** A fresh source trace exports
the mass-4 coastline's actual cubic controls. Integrating those controls with
the fixed MetaPost cubic-arc routine reproduces source q.x increments at times
48–49 and 49–50 to within `0.000006 mm`; the former sampled path intervals
miss them by `0.061 mm`. The time-49 endpoint lies at the fullcircle knot
`(19,37) mm`, but the angle/45 estimate is about `0.00068` circle-time early.
Inverting the fullcircle cubic parameter from the coast endpoint removes that
parameter error. Using that inverse in `_globe-land-outline-data` restores the
mass-4 recursive thin tree from 7 nodes to 31/31 source nodes, with all 31
decisions paired and agreeing. Other traced masses and all brush call totals
are unchanged. The 600 ppi M11 nominal and calibrated raster metrics are
identical: whole/globe/knot RMSE `0.11478531/0.18928662/0.07840452`, versus
the prior `0.11478405/0.18928154/0.07840452`. Keep the inverse mapping: it
restores the source recursive tree without a material raster change. The
remaining q.x residual and mismatches in other recursive levels still need a
source-accurate path-time and fixed-point propagation model.

**S104 fixed-scanline full-row audit (2026-11-05).** A fresh Typst trace was
paired with the pinned 142-row MetaPost log. Reconstructing each hatch segment
with the source 16.16 rotation, half-open crossing rule and fixed-point
intersection yields an average summed endpoint error of `0.000089 mm`, versus
`0.000520 mm` for current Typst endpoints; worst reconstructed row is
`0.000826 mm`. This confirms the source scanline geometry can be recovered
across the panel, but the prior production integration worsened recursive
call/tree agreement and the 600 ppi image gate. Do not apply the endpoint
correction alone: preserve its geometry while propagating matching q curves
and center-path parameterization through recursion.

**M11 knot q-arc reconstruction audit (2026-11-05).** A fresh trace of the
current production lane geometry and source callback input reproduces all 90
thin nodes and all 90 q-control sets exactly when the source cumulative q-arc
knots are supplied for calls 4/lanes 2 and 6, and call 5/lane 2. Current
quarter-sample cubic fits differ from those arc knots by mean absolute
`6.0–7.8` 16.16 units and maximum `17–24`; fifth-sample fitting does not
improve all three lanes at once. This isolates the remaining production gap
to recovering the source q arc clock from generated lane geometry. The traced
arc table remains an oracle only; no source-specific table is enabled in
production.

The current-checkout rerun shows the arc-increment errors alternate in sign:
their per-segment maxima are 24–26 fixed units, but total endpoint drift is
only 2–11 units. The quarter-sample q replay still misses two thin nodes on
calls 4/lane 2 and 5/lane 2 (38/40 and 28/30), with first decision differences
at nodes 33 and 20; call 4/lane 6 stays exact at 20/20. This rules out a
single whole-lane length scale as a general correction. The next diagnostic
should compare local arc increments around those branch points and establish
whether their residual is introduced by lane-point quantization or by
post-shadow segment reconstruction. `diagnostics/audit_m11_lane_arc_drift.py`
now validates the source arc table and reports per-segment error extrema,
endpoint drift, and the first divergent node's q-time interval. Those
intervals cover segments 31–32 and 19–20; the critical latter segments are
short by 21 and 20 units, while their predecessors are high by 2. Pointwise
geometry errors peak one segment earlier, so the next probe needs to separate
quarter-sample reconstruction from the underlying source/Typst curve residual.
The new dense 16-chord replay restores exact source trees for calls 4/lane 2
and 5/lane 2, but changes call 4/lane 6 from 20 to 22 nodes. It is diagnostic
only and does not yet justify a production q-clock rule or raster trial. A
1/2/4/8/16-chord sweep produces trees `38/22/30`, `38/22/28`, `40/22/28`,
`38/22/28`, and `40/22/30` against source `40/20/30`, despite endpoint drift
falling from thousands of units at one chord to at most nine at sixteen.
Recursive decisions therefore do not converge with arc-density alone.
Current q-tree replays put the estimator tradeoff at `38/20/34` nodes for
quarter-sample cubic integration, `38/22/30` for fifth-sample fitting, and
`40/22/30` for 64-chord polylines, against source `40/20/30`. No estimator
reproduces all three lanes, so a lane-specific or fixed-density switch would
move the discrepancy rather than solve it. The missing source post-shadow
lane cubic construction remains the production target.
At call 4/lane 6's first divergent node, a 64-chord replay maps to source
segments 6–8; their local arc errors are only `+1/+2/-11` fixed units. The
paired node has exact width controls and at most 14 units of q-arc control
error, yet the source stops while the replay recurses. The mismatch is thus
highly sensitive to cumulative q-arc placement and its intersection decision,
not to width-control generation. The lane audit and tree comparator now print
these local q-map/control residuals directly.

**M11 shadow outline sampling check (2026-11-05).** Rebuilding the shadow
silhouette with `per: 0` on source-sampled inputs instead of the helper's
default `per: 12` produces identical 600 ppi M11 regional RMSE and ink
coverage. The candidate was reverted; shadow-mask differences need a better
source lane/cut mapping, not a higher density setting in this helper.

**M11 arc-to-cubic lane mapping trial (2026-11-05, rejected).** A candidate
reparameterized each recovered centerline cubic by a 64-chord local arc table
before evaluating tube lanes, normals, and radius slope. On the three traced
post-shadow lanes, the Typst thin-node counts changed from baseline
`40/22/30` to candidate `38/20/28`, against source `40/20/30`: lane 4/6
became exact, while lanes 4/2 and 5/2 each lost two nodes. Maximum point
errors against the source lane cubics increased from
`0.000531/0.000573/0.000550 mm` to
`0.000743/0.000835/0.000760 mm`. Local q-arc errors remained as large as
20–26 fixed units. The candidate was removed without a raster trial; a
generic arc-to-parameter inverse is not a sufficient replacement for the
source offset-lane construction.

**M11 pre/post-shadow lane geometry audit (2026-11-05).** A dense comparison
of the three known source/Typst lane pairs (`4/2`, `4/6`, `5/2`) against the
current production layout finds pre-shadow mean point errors of
`0.0000074/0.0000062/0.0000065 mm`; mean tangent errors are
`0.0766/0.0776/0.0779°`, with maxima below `0.18°`. This rules out a large
pre-shadow lane normal error on these paths. Reconstructing the post-shadow
paths with the current splice map raises mean point error to
`0.000181/0.000186/0.000214 mm`. The first q-tree divergence intervals
(`4/2` segments 31–32 and `5/2` segments 19–20) have similar local errors,
not the worst peaks, so a single local arc increment adjustment is not
supported. The next comparison should pair post-`shadowCut` cubic endpoints
and parameter ranges directly to the pre-cut dense lane, then correct the
general splice/time mapping before changing q-arc integration. The new
`diagnostics/audit_m11_lane_tangents.py` measures pre-cut position and tangent
residuals; `extract_m11_typst_q_inputs.py --show-segment-errors` reports the
post-cut per-cubic position residuals.

**M11 dense-lane convergence and evolving cut-time audit (2026-11-05).**
Increasing the lane trace from 16 to 64 subdivisions per `piece.times`
interval (2,304 to 9,216 intervals on the paired lanes) leaves the old
post-cut mean/max errors unchanged to the reported precision:
`0.000181/0.000531`, `0.000186/0.000573`, and `0.000214/0.000550 mm`.
Polyline density is not the cause. Directly projecting each traced post-cut
cubic endpoint onto the paired 64-subdivision Typst lane shows that the
noninteger endpoint times match the first `M11CUT` parameter ±0.05 to within
one dense sample. For `4/2`, the first cut `21.78946` yields endpoints at
`21.73828/21.83984`; after the first cut adds two segments, the second cut
`28.06259` maps to source-lane times `26.01172/26.11328`. The same pattern
holds for both cuts in `4/6` and `5/2`. This confirms the first field is the
evolving lane cut clock, despite its `pathShadowCut` name. Replacing it with
the second parameter (`xpart(pathShadowIntersection)`) makes the `4/2` splice
map one segment short (39 vs the traced 40) and was reverted. The remaining
`~0.0002 mm` mean residual therefore comes from how post-cut connector cubics
are reconstructed from the shadow path, not from a denser sample grid or a
simple field swap. `diagnostics/audit_m11_postshadow_endpoints.py` records the
endpoint-to-lane projection and its noninteger cut-boundary matches. Production
rendering is unchanged.

**M11 shadow-cut endpoint preservation (2026-11-05).** A direct comparison of
the pre-cut source lane cubic with the emitted post-shadow cubic endpoints
shows that `shadowCut` preserves its trimmed endpoints within
`0.000004–0.000017 mm` on paired calls 4/2, 4/6, and 5/2. Later cuts are mapped
back through earlier inserted gaps. This rules out endpoint displacement as
the source of the post-shadow mismatch; connector control reconstruction and
callback time mapping remain open. The earlier nearest-sample endpoint check
overstated the endpoint error because it did not project onto lane segments;
`audit_m11_postshadow_endpoints.py` now uses continuous segment projection.
The source instrumenter also emits `M11SHIFTEDSHADOW` cubic records at each
tube recursion call to support direct pairing of shifted shadow geometry.
Production rendering is unchanged.

Run the source endpoint check with:

```sh
nix develop path:./nix --command python diagnostics/audit_m11_shadow_cut_preservation.py \
  /tmp/m11-q-audit/trace.log
```

The source-side `shadowCut` loop also advances each shadow path by `1/5` path
time after a hit, while removing `1/20` path time on either side of the hit
from the current lane. In the fresh source trace, lane 4/2 cuts at current
times `21.78946` and `28.06259`; its lane length advances `36→38→40`, while
the remaining shifted-shadow length falls `74→49→23` before the final miss.
Lane 4/6 has three hits (`23.81978`, `28.67752`, `0.99225`) and finishes at
length 41; lane 5/2 has two (`9.78946`, `16.06259`) and finishes at 40. This
is a concrete source-order/cursor invariant for the next implementation
probe. It does not mean the current polygon shading should erase those whole
intervals: `shadowCut` affects each generated lane before brush subdivision,
whereas Typst currently applies projected polygon membership at shading
samples. A previous direct comparison of old Typst trace time `21.7` against
source lane time `21.7` was invalid because those traces did not share a
parameter origin; only the separately projected endpoint check establishes
geometric correspondence. Do not use that stale time pairing to tune
production.

**M11 projected shadow sample pairing (2026-11-05).** The diagnostic's source
to Typst shadow outline map was wrong for all three occluded calls. Correcting
it and evaluating both source and Typst outlines at the source-recorded
light-sample positions, with the same traced depth and light vector, yields
identical classifications for all 1,004 samples across calls 4/5/6: 154
shadowed and 850 unshadowed. The paired silhouettes therefore need no
geometry correction at these recorded sample positions. This is a sampled
classification check only; it leaves the lane's `shadowCut` parameter splice,
callback phase and recursive brush path unresolved. The revised comparison
is in `diagnostics/compare_m11_shadow_polygons.py`.

Run the endpoint audit against a 64-subdivision lane trace with:

```sh
nix develop path:./nix --command python diagnostics/audit_m11_postshadow_endpoints.py \
  /tmp/m11-q-audit/trace.log /tmp/m11-knot-tube-trace-64-flat.json \
  --samples-per-cubic 256
```

Reproduce against a fresh trace in the repository devshell with:

```sh
nix develop path:./nix --command python diagnostics/audit_m11_lane_tangents.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace-current.json
nix develop path:./nix --command python diagnostics/extract_m11_typst_q_inputs.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace-current.json \
  build/m11-production-q-inputs.typ --dense --dense-factor 16 \
  --show-segment-errors
```

**Strand-knot variable-width callback continuity (2026-11-05).** Commit
`f3fb5f8` carries per-strand width callbacks through crossing-created gap and
mask fragments using each fragment's distance range on the original strand.
The crossing clearance, tube shadow silhouette, and lower-layer erasure mask
now query the same whole-strand width law. A variable-width, multi-crossing
Typst probe and the existing `knot.typ` and `main.typ` specimens compile in the
declared Nix devshell. This verifies execution and keeps callback phase from
restarting at each fragment; it is not yet a source-parity result because the
pinned MetaPost source callback has not been traced at these crossing
locations. Add a source-level callback comparison before using it to claim a
raster-fidelity improvement.
