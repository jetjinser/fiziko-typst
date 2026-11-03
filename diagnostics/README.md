# Diagnostics

This directory keeps reproducible investigation sources and two historical
Figure 12 CSV snapshots. Generated PDFs, images, logs, and instrumented
upstream copies belong in `/tmp` or `build/`, not in version control.

## Stage 2 seeded MetaPost random stream

The pinned devshell provides MetaPost 2.11. The comparison pipeline uses its
default `scaled` number system: the stream is initialized from the seed after
16.16 conversion, then advances the 55-value subtractive recurrence described
in the [MetaPost engine source](https://github.com/TeX-Live/texlive-source/blob/trunk/texk/web2c/mplibdir/mp.w)
and [scaled arithmetic implementation](https://github.com/TeX-Live/texlive-source/blob/trunk/texk/web2c/mplibdir/mpmath.w).
Double mode uses a different generator and is not the compatibility target.

`metapost-rng-vectors.mp` is the MetaPost oracle; `metapost-rng-vectors.typ`
asserts the first 16 values for `randomseed := 1` against the Typst port. Check
them in the repository's devshell:

```sh
nix develop path:./nix --command mpost -interaction=nonstopmode diagnostics/metapost-rng-vectors.mp
nix develop path:./nix --command typst compile --root . diagnostics/metapost-rng-vectors.typ /tmp/metapost-rng-vectors.pdf
```

`sphere-latitude(..., rng: "metapost")` is the first draw-order pilot. M3's
nominal whole-plate RMSE at 600 ppi improved from 0.07233 to 0.07143; dark
coverage shifted from 0.01% above the source to 0.69% below it. The Typst
render time rose from 40.3 s to 47.6 s for that plate. The option remains
explicit while other drawing families still use keyed randomness and their
MetaPost call order has not been ported. See the paired artifacts under
`build/source-parity-rng/` and the [fidelity plan](../comparisons/fidelity-plan.md).

Longitudinal `tube(..., rng: "metapost")` now carries the same cursor through
section-major lane traversal. On M4 its nominal 600 ppi RMSE changes from
0.07127 to 0.07109; unit-aware 16.16 thin-brush threshold rounding lowers it
further to 0.07025. Dark coverage before that change was 1.8045% (source:
1.8385%). The M7 transverse pilot worsened RMSE from 0.12453 to 0.12532, so
the option is deliberately restricted to longitudinal tubes. M11 boundary
lane calls are now traced, but variable-radius boundary behavior and exact
subdivision still differ, so this is not yet a complete tube RNG port.

S102's outline-only tube uses two source MetaPost `..` joins through three
points. Typst's `tube` reconstructs their Hobby curve, then approximates the
offset outlines with `per` samples per segment. The comparison fixture's
former `per: 8` leaves visible faceting against the source cubic. Raising it to
64 lowers 600 ppi tube-crop RMSE `0.07861 → 0.01821` and whole-plate RMSE
`0.06951 → 0.04909`; tube dark-ink coverage moves from 0.6135% to 0.6195%
against 0.6208% source. The sphere crop is unchanged at 0.09110. Intermediate
densities 16 and 32 also improve monotonically, but 64 better resolves the
outline at the measurement scale. This is a comparison-specific sampling
setting; the `tube` API and its caller-controlled `per` value are unchanged.

A separate sphere-shadow probe removed the per-sample shadow override and used
only the source ring's eight lightness callback knots. This brought sphere
dark coverage from 5.9547% to 5.5558% against 5.6997% source, but sphere-crop
RMSE regressed `0.09110 → 0.10564` and whole S102 RMSE regressed
`0.04909 → 0.05650`. Revert the probe; the eight source callbacks also depend
on `shadowCut`'s inserted path knots, so simply dropping the denser shadow
classification does not reproduce their width path.

The pinned `tubeGenerate` loop includes both boundary lanes (`k=0` and
`k=bw1`). The first M4 pilot drew them with sampled offset geometry; it raised
ink coverage from 1.751% to 1.835% against 1.789% source and slightly
regressed RMSE (0.07025 to 0.07031), so it was removed. A later source-derived
implementation now uses each recursive section's endpoint lane, width law,
and source draw order. On M11 it improves the knot crop, but it still needs
better geometry and has cross-plate coverage tradeoffs; see the M11 knot
trace below. Constant-radius M4 boundary paths consume no dash calls, while
variable-radius boundary-call behavior remains open.

`_ink-loops(..., source-rounding: true)` now rounds the scalar interpolation
fraction to 16.16, rounds each width-times-fraction product as a dimensional
MetaPost value, and rounds their sum. The fraction and width use different
quantizers; treating `1 - fraction` as a length produced the wrong units and
was corrected before final measurements. At 600 ppi, paired same-checkout
reports show M4 RMSE `0.06017598 → 0.05947335`, M11 `0.11295018 → 0.11289878`
and its knot crop `0.05881920 → 0.05823034`, and S105 `0.10214839 →
0.10213793`. M9 changes by only `+0.00000057`; S104 changes by `+0.00001057`
(hatch crop `+0.00005715`). The remaining 15 plates have identical regional
metrics. All 20 cases rendered successfully. M11 brush call counts remain
`224` source versus `226` Typst; this width-arithmetic fix improves the raster
but does not yet match recursive call trees.

## WoodBlock source-field pilot

`wooden-thing(..., source-field: true)` and `wood(..., source-field: true)`
now use the source `woodBlockRes` as an explicit `source-res` parameter. M9's
reference driver overrides it to 1 mm; other source examples use the 1/3 mm
default. The field equations now follow the source grid index, 0.2 detail
scale, elliptic knot radius, angle convention, per-column displacement and
low-frequency perturbation. The first M9 panel's 72 sampled lattice values
match the pinned source with mean error 0.00029 (normalized by `rho=1/24`),
maximum error 0.00151; the source maximum occurs at `(6,42)` and matches to
0.00062. The first source contour path pairs with a Typst path within about
0.11 mm mean vertex distance. Source level thresholds preserve the fractional
phase of the sampled maximum and subtract the source's positive jitter.
Landscape knot coordinates now use the same reflected short-axis transform
as the field. Source panel stream offsets remain 0, 1456, 2823 and 4120.

At 600 ppi M9 whole-plate RMSE moves from 0.22407 to 0.21526 with uniform
contours, then to 0.21328 with `contour-brush: "cell-range"`; ink coverage is
3.778% versus 4.203% source. S105 also uses the source field equations and
1/3 mm resolution. Its current score is 0.10304 (block 0.12838, surface
0.07851), a regression from the earlier tuned 0.09792. Keep this tradeoff
visible while the remaining contour width and brush calls are aligned.

S105's landscape transform and stream continuity now follow the pinned source
trace; the contour-brush rendering and per-brush call count remain different.
The instrumented S105 source reports a 52 × 8 mm rounded `woodBlock` extent
and 536 global random calls before its first surface knot. The source's first
internal candidate is (8.2726, 46.3121) mm; the Typst stream at offset 536
produces (8.27285, 46.31245) mm. The fixture extents are integer millimetres
(and therefore exact multiples of the 1/3 mm source resolution); threading
that offset lowers S105 600 ppi whole RMSE from
0.10635 to 0.10553; block RMSE is 0.13244 and surface RMSE is 0.07909 (surface
ink 0.599% vs 0.489% in the source).

Wood contours are now kept as connected paths through polygon clipping, so a
stroke continues across marching-grid vertices instead of restarting at each
edge. The 600 ppi M9 score changes from 0.22412 to 0.22411; S105 changes from
0.10553 to 0.10555. This makes path continuity match `cLine` more closely but
does not materially reduce raster error; source brush width, dash recursion,
and random-call behavior remain the larger gap.

`contour-brush: "cell-range"` applies the source `cLine` per-cell width law
to the connected contour path. `_woodblock-field` stores the source field
divided by `rho = 1/24`, so this mode restores the unnormalized range before
computing width. With the former approximate field it improved S105 but
regressed M9; after the source field and level phase were aligned, M9 improves
from 0.21526 to 0.21328. S105 remains worse than its prior tuned candidate,
so keep its score as a separate gate. Exact `v[st]` interpolation, recursive
leaf placement and global dash-call phase remain open.

A pilot that linearly interpolated cell ranges between adjacent geometric
contour segments attempted to model `v[st]` interpolation. It regressed S105
600 ppi RMSE from 0.09792 to 0.09898; block and surface crops regressed from
0.12095 to 0.12250 and 0.07598 to 0.07648. The pilot was reverted. Geometric
segment order is not a reliable substitute for `cLine`'s recursive `st`
sequence, so the next width-law change needs a source traversal trace.

`instrument_wood_contours.py` records the first source `cLine` level, source
field range, selected field samples, path vertices, and traversal's
`(i, j, st, cell-range, direction)` values. For M9 the first visits begin
`(0,12,0)`, `(0,13,1)`, `(1,13,2)`, `(1,14,3)` and continue for 19 cells;
`st` rises and falls according to the recursive walk, rather than a simple
row or geometric-segment order. A 1/3 mm contour-grid pilot, combined with the
source-rate random-column offsets, increased ink coverage and regressed M9 to
0.22506 and S105 to 0.13050. That pilot was reverted. Field samples and the
first contour geometry now have direct source comparisons. Source-indexed
width interpolation is modeled below; recursive leaf placement and dash
coverage remain open.

The trace now includes out-of-bounds cells and `CLSPAN` (`sqB`, `sqBm`, and
path length). In the first M9 path, the two exterior cells are
`(-1,22,19)` and `(-1,12,-1)`; after transforming back to source grid
coordinates, the reversed Typst path cell sequence matches the in-bounds
`cLine` traversal. This establishes traversal correspondence for that path,
but a prototype that projected the source per-cell width profile onto the
clipped Typst vertices produced M9 RMSE 0.214688, worse than the retained
0.213280. That production prototype was reverted; it projected the cell
profile onto vertices without preserving the source path-time orientation.

The exterior `cLine` calls return their grid coordinates `(i,j)` directly;
they are not cell midpoints. With M9's landscape transform the two endpoints
become `(22,34)` and `(12,34)`. `replay_wood_cline.py` now replays the directed
`cLine` recursion from the traced field values and starting cell, including
its edge order, visited-cell state, and `st`-dependent path orientation. It
also assigns each output segment to its traced `st` and cell range. In the
first path, `iL` segment states descend from `19` to `-1`; the brush input
`reverse(iL)` therefore consumes `-1` through `19`, with both boundary
segments carrying zero cell range. Run it on the saved MetaPost trace with:

```sh
nix develop path:./nix --command python diagnostics/replay_wood_cline.py \
  /tmp/m9-cLine-trace/trace.log
```

On the current trace it reproduces all 22 vertices in order, visits the same
19 in-bounds cells, and has maximum point error `0.000718 mm`. The residual is
consistent with `CLVALUE` being printed to five decimal places. This validates
the source traversal model independently of the Typst contour stitcher; it
does not by itself validate renderer output.

`contour.typ` now also implements this traversal iteratively as
`marching-squares(..., source-walk: true)`, avoiding deep recursive Typst calls.
`wooden-thing` uses it for source-field contours; the grid contour path in
`wood` retains marching-squares. The first M9 path has 22 points in the source
order and an outer brush length of 17.2651 mm versus 17.2808 mm source. Its
600 ppi full-plate RMSE changes `0.212742 → 0.212436`, with ink coverage
`3.7497% → 3.7804%` (source: `4.2032%`). Against a matching same-checkout
baseline, S105 whole-plate RMSE changes `0.102443 → 0.102628`; its block crop
is unchanged at `0.127927`, while surface crop changes `0.077655 → 0.078106`.
Ink coverage moves closer from `0.6960%` to `0.7004%` (source: `0.7405%`).
The source traversal is retained because its path topology follows the pinned
source and M9 improves, with the S105 crop tradeoff recorded. Recursive brush
decisions remain 11 outer and 48 thin nodes versus source 37 and 65; production
still clips paths before brushing.

The replay's per-segment states establish the source width-time knots. `iL`
segments descend `st=19…-1`; `reverse(iL)` consumes `st=-1…19`. Both exterior
segments have zero range. `stroke-ink` now supports normalized path-time samples,
and `_wood-source-width(..., source-time: true)` maps those ranges to width
knots, including the two terminal samples set to 1. On the full first M9 path,
all 22 Typst width samples match the MetaPost `CLWIDTH` callback within
`2.93e-5 mm` mean and `9.91e-5 mm` maximum. Tree pairs within 0.1 mm improve
from `33/42` to `36/42`, recurse/stop agreement remains `37/42`, and dash-leaf
pairs improve from `7/12` to `8/12`.

Applied to clipped production paths in the source brush direction, the
path-time profile lowers 600 ppi M9 RMSE `0.212436 → 0.211560`; M9 ink coverage
falls `3.7804% → 3.7120%` (source `4.2032%`). S105 RMSE improves
`0.102628 → 0.102148`; block crop stays `0.127927`, surface crop improves
`0.078106 → 0.076936`, and surface ink coverage moves `0.5518% → 0.5309%`
toward `0.4892%` source. Retain the profile with its M9 coverage tradeoff.
Because production clipping removes the two exterior source segments before
brush recursion, it still lacks the full source `st` sequence. Full-path
brushing followed by clipping the generated ink remains open.

The pinned `isoLines` source confirms the exact width lookup: except for the
terminal unit of the path, it interpolates `v[floor(sqB + offsetPathTime)]`
and `v[ceiling(sqB + offsetPathTime)]`; `cLine` fills each `v[st]` with that
cell's scalar range. In the first traced M9 path, `sqB=-1`, `sqBm=19`, and
`length(iL)=21`, while recursive cell visits assign the `st` sequence. A
paired Typst path has 20 visible vertices versus the source's 22; after the
source landscape transform, its 19 segment cell ranges match the reverse
source `v[st]` sequence. The mean absolute range error is `1.54e-5` and the
maximum is `4.92e-5` in source field units. This follows from the source
passing `reverse(iL)` to `brushGenerate` while building the width template on
forward `iL`: the visible path starts with the terminal fallback, then uses
the reversed cell ranges. `_wood-source-width` now models that sequence and
its path-time interpolation. On matched 600 ppi runs, M9 RMSE changes from
`0.213294` to `0.212745`; S105 changes from `0.103137` to `0.102450`, with
block/surface crops changing from `0.128550/0.078508` to
`0.127935/0.077662`. Ink coverage moves slightly farther below source on both
plates (M9 `3.777% → 3.749%`, source `4.203%`; S105 `0.715% → 0.696%`, source
`0.741%`). Keep the width mapping for its lower pixel error, while treating
the remaining under-coverage as an open difference. The `CLWIDTH` source
records include the `offsetPathTime`, `sqB`, `sqBm`, path length, interpolated
`v[st]` values, and terminal fallback.

`_wood-source-width` now rounds each normalized corner back to the source
field's 1/24 scale and 16.16 precision, then rounds the interpolated variation
and dimensional brush width at their source arithmetic boundaries. Controlled
600 ppi renders lower M9 RMSE from `0.212745278` to `0.212742096` and S105 from
`0.102449940` to `0.102442922`. M9 ink coverage moves slightly toward source
(`3.74904% → 3.74969%` vs `4.20316%`); S105 moves slightly away
(`0.69618% → 0.69603%` vs `0.74053%`). Keep this small pixel-error improvement
with the coverage tradeoff recorded.

A fresh paired trace localizes the remaining M9 end-intersection residual to
the field maximum and first contour level. Source `CLFIELDFIX` records the
first block maximum as `13632/65536 = 0.2080078125`; the Typst sampled maximum
is `4.9928571449/24 = 0.2080357144`. On the source edge corresponding to
Typst model samples `(0,12)` and `(0,13)`, the source fixed-point values are
`10204/65536` and `10758/65536`; Typst reports `3.7375370140/24` and
`3.9395665455/24`. The source contour level is `-10675/65536`, while the
Typst level divided by its 24x field scale is `0.1629227866`. The source
jitter is `226/65536`; Typst's first contour draw at RNG offset 204 is
`0.6616821289`, which MetaPost's `uniformdeviate(1/192)` rounds to the same
16.16 value. Thus the random-call position matches. The observed endpoint
discrepancy (about `0.004–0.005 mm`) is already present in the maximum/level
inputs; it is not a path-direction, boundary-stitching, or RNG-offset error.
At the maximum cell `(6,42)`, the source decomposes its value into
`wField = 13341/65536 = 0.20356750` and column offset
`291/65536 = 0.00444031`, summing to the recorded maximum. Typst's diagnostic
decomposition is `wField = 0.20359104` and offset `0.00444468`; its column RNG
sample at index 176 is `0.85337830`, which rounds through
`uniformdeviate(1/192)` to the same `291/65536`. The residual is therefore in
the `wField` arithmetic, not the column RNG. The traced first accepted knot
also agrees with Typst within 0.0003 mm after converting MetaPost bp to mm.
At the maximum cell, source cumulative knot terms are
`0.01373291, 0.23362732, 0.24186707, 0.23954773, 0.27470398`; corresponding
Typst terms with only `detail`/`rho` source-rounded are
`0.01373820, 0.23362618, 0.24187107, 0.23956109, 0.27472421`. The largest
remaining increase occurs in the last two knot contributions, so matching the
constants alone does not reproduce MetaPost's intermediate fixed-point
operations.
Field-operation 16.16 rounding previously improved lattice samples but
regressed both M9 and S105 renders, so do not apply a global field correction.
Next, reproduce the source maximum-field arithmetic for level selection
without changing contour corner values, then test that level-only candidate
against both wood plates.

A narrow candidate rounded only the sampled maximum to 16.16 before deriving
the source contour levels, leaving all contour-corner samples untouched. On
same-checkout 600 ppi reports, M9 RMSE changed `0.21156032 → 0.21154594`, but
S105 changed `0.10213793 → 0.10213956`; its block/surface crops both regressed
(`0.12790793/0.07693635 → 0.12790896/0.07693895`). The M9 ink coverage was
effectively unchanged. Its first-path end intersection also moved from
`(12.854379,33)` to `(12.854690,33)`, farther from source `(12.85017,33)`.
The small M9 pixel gain is not a consistent fidelity improvement, so the
production change was reverted.

A separate source-constant candidate set `woodBlockDetail` and
`woodBlockYRdensity` to their MetaPost 16.16 values while leaving the other
field operations floating point. It moved the first M9 crossing closer to
source (`x=12.85438 → 12.85284 mm`, source `12.85017 mm`), but 600 ppi RMSE
regressed on M9 (`0.21156032 → 0.21170117`, all four panel crops) and S105
(`0.10213793 → 0.10214326`; block `0.12790793 → 0.12791856`). Surface crop
improved only `0.07693635 → 0.07693501`. Constant quantization alone is
insufficient; the production change was reverted.

To capture the source traversal from the pinned M9 driver:

```sh
mkdir -p /tmp/m9-cLine-trace
python3 diagnostics/instrument_wood_contours.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m9-cLine-trace/fiziko.mp
cp comparisons/reference/main.mp /tmp/m9-cLine-trace/main.mp
printf 'selected := 9; input main.mp;\n' > /tmp/m9-cLine-trace/trace.mp
(cd /tmp/m9-cLine-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'CLSTEP' /tmp/m9-cLine-trace/trace.log
rg 'CL(FIELD|VALUE|LEVEL|PATH|WIDTH)' /tmp/m9-cLine-trace/trace.log
rg 'CLW(R|TERM|BASE|FINAL)|CLMAXCELL|CLDRAWFIX' /tmp/m9-cLine-trace/trace.log
rg 'WB(NODE|CUT|LEAF|TCALL|THIN|THINDASH)' /tmp/m9-cLine-trace/trace.log
typst eval 'query(<m9-contour-walk>).first().value' \
  --in diagnostics/m9_contour_walk_trace.typ --root . \
  > /tmp/m9-cLine-trace/typst.json
python3 diagnostics/compare_wood_contours.py \
  /tmp/m9-cLine-trace/trace.log /tmp/m9-cLine-trace/typst.json
```

`m9_field_fixedpoint_probe.typ` isolates the known source minimum cell
`(33,29)` and emits the per-knot fixed-point radius, angle and cumulative
field terms. Compare it with `CLWRFIX`, `CLWTERMFIX`, `CLWBASEFIX` and
`CLWFINALFIX` from the source trace. The probe derives raw-fraction knot
positions from seed 1, applying the traced 28-call brush consumption after
each accepted knot; its first three cumulative knot terms match the source
trace exactly. It also exports a 72-sample fixed-point grid using those
derived positions. Pair those values with the first 72 `CLVFIX` records and
subtract the matching first-block `CLCOL` offset for each column; `CLCOL`
records the source column jitter as two base-256 digits. This comparison is diagnostic
only and does not alter rendering. To reproduce the summary:

```sh
nix develop path:./nix --command typst eval \
  'query(<m9-fixed-field-probe>).first().value' \
  --in diagnostics/m9_field_fixedpoint_probe.typ --root . \
  > /tmp/m9-cLine-trace/field-probe.json
nix shell nixpkgs#python3 --command python3 \
  diagnostics/compare_m9_field_samples.py \
  /tmp/m9-cLine-trace/trace.log /tmp/m9-cLine-trace/field-probe.json
```

The same trace now instruments `brushGenerate` for the first accepted M9
contour. `WBNODE` records recursion depth, width extrema in millimetres, cut
time and path length; `WBCUT` records the cut point; `WBLEAF` records whether
a node ends as a filled band or a thin brush. The pinned source trace has 37
outer nodes and 19
leaves. Its first root splits at path time `4.7189`; an accepted fill leaf
appears at depth 1, while a thin-brush branch reaches the recursion limit of
10. `compare_wood_contours.py` pairs the source log with Typst metadata. It
accounts for `isoLines` adding the source level to the field, the source to
Typst field scale of 24, and the reflected landscape axes. Source level
`-0.16289` maps to Typst level `3.91015`; the matched path has an exact
reversed 19-cell visit sequence. Its mean/max source-point distance is
`0.108/1.315 mm` (the maximum is at the source's one-cell boundary
extension), while reversed per-cell ranges differ by `1.54e-5` mean and
`4.92e-5` max. With the production-matched `per: 0` trace, the root cut point
is `0.00383 mm` from source, but its path length is `14.5469 mm` versus
`17.2809 mm` in source. The source records 37 outer nodes and 19 leaves.
Supplying source-rounded 16.16 width-template knots to the diagnostic brings
the first Typst brush tree to 41 outer nodes; contour geometry and root length
are unchanged. The open wood gap is brush recursion and the boundary it draws,
not cLine cell discovery.

The trace also follows `thinBrushGenerate` into its recursive thin branches
and dash leaves. Set `per: 0` in `m9_contour_walk_trace.typ` to match the
production call in `wooden-thing`; omitting it silently resamples every
segment into a Hobby curve and gives a different brush tree. The older 7/46
node, 10-dash figures and their parent-pair metrics came from that incorrect
default and are withdrawn. With the corrected production setting, the source
has 66 thin-brush calls, 65 split/terminal nodes through depth 15, and 12 dash
leaves. With source-rounded 16.16 width-template knots, Typst has 50 thin
nodes, 12 dash leaves and 24 RNG calls, exactly matching the source's dash
and RNG totals; without those knots it had 48 thin nodes. `WBTCALL` and
`WBTHIN` carry call IDs, so
`compare_wood_contours.py` reconstructs both recursion forests, pairs their
roots geometrically, then pairs each parent's children by endpoint error. The
no-knot parent-aware walk pairs 42 nodes, has 36 pairs within 0.1 mm and
37/42 matching recurse/stop decisions. With source width knots it pairs 44
nodes, has 37 within 0.1 mm and 40/44 matching decisions. The first two
remaining divergences are still close (0.0032 and 0.0024 mm); two later
pairs remain far apart (about 0.393 and 0.500 mm). Source/Typst dash leaves
still pair 8/12 times within 0.1 mm. These are
geometry-guided parent pairs, not proof of identical trees; the close branches
narrow the source audit to width-level selection and endpoint/candidate
validity without justifying a global threshold change.

A fresh pinned-source trace identifies an earlier geometric mismatch that
should be resolved before those local branch decisions. MetaPost's
`woodBlock` draws `isoLines` into an intermediate picture, then clips that
picture to the block polygon; therefore `brushGenerate(reverse(iL))` sees the
full `cLine` path, including its one-cell boundary extensions. In the first
M9 contour, the source trace has 22 path points, while the paired Typst contour
has 20 after `_clip-polyline-paths` runs before `_wood-source-width` and
`stroke-ink`. The source endpoints transform to `(22,34)` and `(12,34)` in the
Typst landscape coordinates, beyond the block's `y=33` edge; the Typst path
instead starts and ends on the clipped boundary. The source path length is
17.28086 mm, versus 14.54685 mm at the original paired Typst outer recursion
root. A renderer candidate appended the source boundary-cell points, brushed
the extended path, and clipped the final ink to the rectangle. It moved the
Typst input length to 16.87318 mm. With the corrected `per: 0` trace, the
candidate has 9 outer nodes, 46 thin nodes, 11 dash leaves and 22 RNG calls;
the baseline has 11/48 nodes, 12 leaves and 24 calls. The outer cut remains
0.00383 mm from source. Parent-aware pairing falls from 42 to 40 nodes and
decisions from 37/42 to 34/40. At 600 ppi, M9 RMSE regressed from 0.212742 to
0.214788 and ink coverage moved from 3.7497% to 3.7935% against 4.2032% source.
S105 RMSE improved from 0.102443 to 0.102240, but its ink coverage fell from
0.6960% to 0.6912% against 0.7405% source. The renderer candidate was reverted.
The source clip ordering remains confirmed; reproducing the full path alone is
insufficient without matching its width-template and recursive cut behavior.

A follow-up added only the exact source endpoint tuples `(22,34)` and
`(12,34)` to the clipped contour. At `per: 0`, the Typst root length moves
from 14.54685 to 16.87318 mm, while the first cut remains 0.00383 mm from the
source. The tree remains at 11 outer / 48 thin nodes with 12 dash leaves and
24 RNG calls; 42 parent-aware pairs and 37/42 decisions still agree, while
pairs within 0.1 mm move from 34 to 33. A full 600 ppi M9 comparison shows the
visual cost: RMSE rises `0.212742 → 0.214067`, while ink coverage moves closer
from 3.7497% to 3.8294% (source: 4.2032%). S105 is effectively unchanged at
RMSE 0.102443 and coverage 0.6960% (source: 0.7405%). The candidate was
reverted: matching the gross path length and source call count does not
improve the paired M9 image.

The source instrumenter now emits `WBTFIX`, recording `w0`, `w1`, `w2`,
`minWidth`, and `dashStrokeWidthStep` in 16.16 MetaPost point units. At the
first close divergence (source call 10), the source values are
`10335, 9248, 9249, 4353, 544`; its midpoint-to-step ratio is `5439/544 =
9.99816`, so the source floors to level 9 (`w2 = minWidth + 9*step`). The
paired Typst widths land at level 10 and recurse. A one-scalar-unit downward
bias fixes that branch, but the full M9 trace gets worse: parent-aware pairs
fall from 42 to 40, pairs within 0.1 mm fall from 34 to 30, and decision
agreements fall from 37/42 to 36/40. Dash leaves fall from 12 to 11 (22 RNG
calls). At 600 ppi, M9
RMSE improves `0.212740 → 0.212504`, while S105 regresses slightly
`0.102443 → 0.102450`; the M9 ink-coverage deficit also grows. Revert the
bias: one branch is explained, but aggregate tree fidelity does not improve.

The trace also emits `WBQCTRL`, the 16.16 control points of the source width
template passed to `thinBrushGenerate`. For source call 10, its first and last
template values correspond to the logged endpoint widths 0.05563 mm and
0.04977 mm. This makes it possible to compare the actual recursive width
curve, rather than only its extrema and selected level. The source constructs
that template from `iL` using integer `offsetPathTime` samples and then calls
`brushGenerate(reverse(iL), template, 0)`. Typst currently evaluates its width
law along normalized arc fractions of the paired contour. The paths and
sample-time domains therefore need an explicit point-by-point pairing before
changing the width mapping; the new control trace is diagnostic evidence, not
a production renderer change. A Hobby interpolation probe over cumulative
arc/width samples confirmed that evaluating the curve only at the original
contour vertices leaves the 37/11 outer-node and 65/48 thin-node trees
unchanged. Sampling that profile at four subdivisions per contour edge made
the recursion see its interior curvature, but also changed the brush's path-
time grid: same-input 600 ppi RMSE regressed from `0.21274033` to
`0.22116264` on M9 and from `0.10244255` to `0.10595469` on S105. M9 ink
coverage moved closer to source, while S105 overshot it. The densified-path
candidate was reverted. A source-width spline must enter recursion without
changing the original contour parameterization before it can be judged as a
faithful port.

A second probe added a continuous-width callback to `_ink-loops`, so recursive
cuts could query the Hobby profile without adding contour vertices or changing
their path-time grid. This improved neither source tree nor render: the M9
trace fell from 42 to 40 paired thin nodes, from 34 to 24 pairs within 0.1 mm,
and from 37/42 to 31 decision agreements; whole-plate RMSE regressed
`0.21274033 → 0.21301552`. S105 regressed `0.10244255 → 0.10315715`. The
continuous Hobby callback and its production hook were reverted. The generic
Hobby fit over cumulative arc and output widths has not been shown to reproduce
the traced source cubic controls; the next width-template attempt needs to
pair those controls and source times directly.

Thin-node metadata now records widths at both path endpoints. On the paired
call-10 node, Typst's reversed endpoint widths are 0.04978701 and
0.05564368 mm; they pair with the source's 0.04977 and 0.05563 mm within
0.000018 and 0.000014 mm. The endpoint orientation is therefore accounted for
on this branch. The remaining level-9/level-10 split is sensitive to the
small local cell-range difference; a global level bias previously worsened
the aggregate tree and remains reverted. Next compare the exact source and
Typst cell-corner field values feeding these two endpoint widths.

`CLVFIX` now records the first 72 source lattice values as exact 16.16 chunks.
Compared after undoing Typst's 24x contour-field scale and applying the same
16.16 scalar rounding, their mean absolute difference is `1.23e-5` field
units, with `6.10e-5` maximum. Around the branch, source cell `(3,16)` has
range `0.033203125`; the corresponding Typst corners give `0.033157349`, a
`-4.58e-5` difference. The source/Typst value at corner `(4,16)` differs by
three scalar units. This is enough to explain why the branch is numerically
close to a width-level boundary, but it does not establish that adjusting the
field arithmetic will improve the full contour tree; measure such a change
against both M9 and S105.

A probe that rounded major field operations to 16.16 lowered the 72-point
grid mean/max error from `1.23e-5/6.10e-5` to `8.48e-6/4.58e-5`, with exact
source matches increasing from 29 to 37 samples. Its 600 ppi source-parity
render regressed both plates: M9 RMSE `0.212742 → 0.212848` and S105
`0.102443 → 0.102495`. Revert the field-arithmetic candidate; the lower grid
sample error alone did not preserve the contour rendering.

A narrower `source-walk` probe left the field and levels unchanged, rounding
only each edge-crossing parameter and physical contour point to MetaPost's
16.16 grids. Against the same-checkout source-parity reports, M9 RMSE regressed
`0.21155798 → 0.21162015`. S105 changed only `0.10213802 → 0.10213798`, with
block crop `0.12790809 → 0.12790793` and surface crop
`0.07693635 → 0.07693648`. Revert this probe: it does not improve the wood
contour pair as a whole.

MetaPost computes each thin node's `w2` level from the average of its two
endpoint widths. A direct Typst probe using the path endpoint widths was
reverted: on the paired M9 root, Typst reads about 0.07029 mm at both ends
while source has 0.07030/0.03394 mm. The candidate therefore selects the
maximum width level, collapsing tree pairing from 40 nodes to 4 and dash
leaves from 10 to 1. The probe confirms that source's endpoint formula cannot
be transplanted until the width template and path-time mapping are aligned.

The instrumented M9 source now also records the random calls made by each
accepted knot's five brush rings. The first knot consumes `[14, 6, 6, 2, 0]`
calls, 28 total, between its candidate-position draws and the next knot. A
96-point Typst ellipse passed through the current generic brush recursion
consumes `[74, 72, 68, 58, 38]`; it over-subdivides the small curved rings, so
copying the source ring widths into `stroke-ink` made the M9 comparison worse.
`wood_knot_ring_counts.typ` reproduces that Typst count. The ring shape and
dash recursion need a curve-aware port before replacing the current knot mark.

`wood_knot_resolution_counts.typ` probes `_ink-loops` with source-rounded width
levels sampled from the eight `fullcircle` knots. Its eight-point polygon gets
`[14, 10, 6, 2, 0]` calls, close to the source `[14, 6, 6, 2, 0]`; increasing
the polygon resolution overshoots sharply. The eight-point centerline is only
a call-count probe, not acceptable circle geometry. The remaining ring-2
difference reinforces that the next port needs separate cubic path geometry
and the source's eight-knot, arc-length width template.

An opt-in `_ink-loops(..., width-by-arc: true)` diagnostic now interpolates the
sampled width values by cumulative centerline distance instead of frame index.
On this polygon probe it produces exactly the same counts at every tested
resolution (8 points still gives `[14, 10, 6, 2, 0]`). Thus arc interpolation
alone does not explain the extra four calls in ring 2; the next useful trace
must use the source cubic `fullcircle` geometry and its actual width-knot arc
positions. The option is internal and is not enabled by the public wood
renderers.

The cubic path is now traced separately by `wood_fullcircle_trace.mp` and
`extract_wood_fullcircle.py`. The renderer's existing eight-segment cubic
sampler matches the pinned MetaPost points at 1/32 path-time spacing with a
maximum normalized coordinate error of `0.0000309`. Feeding that geometry and
its actual arc-positioned width knots into `_ink-loops` reproduces the source
first-knot counts exactly: `[14, 6, 6, 2, 0]` (28 total). This only establishes
the path and recursion-call model. Rendering those rings through the current
Typst band builder raised M9 RMSE from `0.22442` to `0.22843` and ink coverage
from `4.273%` to `4.468%` (source `4.203%`), so the production renderer was
restored. The mismatch now points to brush offset geometry or leaf rendering,
not the cubic centerline or call count.

Regenerate the checked-in path trace in the locked Nix shell:

```sh
mkdir -p /tmp/wood-fullcircle-trace
cp "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/wood-fullcircle-trace/fiziko.mp
cp diagnostics/wood_fullcircle_trace.mp /tmp/wood-fullcircle-trace/
(cd /tmp/wood-fullcircle-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace \
    wood_fullcircle_trace.mp)
python3 diagnostics/extract_wood_fullcircle.py \
  /tmp/wood-fullcircle-trace/trace.log diagnostics/wood_fullcircle_path.typ
typst eval 'query(<wood-knot-fullcircle-counts>).first().value' \
  --in diagnostics/wood_knot_fullcircle_counts.typ --root .
```

`wood_knot_trace.typ` exports the first M9 plank's model and transformed knot
coordinates. To record candidate positions and per-knot random-call counts
from the pinned MetaPost source, run inside the Nix devshell:

```sh
mkdir -p /tmp/m9-source-trace
python3 diagnostics/instrument_wood_knots.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m9-source-trace/fiziko.mp
cp comparisons/reference/main.mp /tmp/m9-source-trace/main.mp
printf 'selected := 9; input main.mp;\n' > /tmp/m9-source-trace/trace.mp
(cd /tmp/m9-source-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'WKCAND' /tmp/m9-source-trace/trace.log
rg 'WKRAND' /tmp/m9-source-trace/trace.log
typst eval 'query(<m9-wood-knot-trace>).first().value' \
  --in diagnostics/wood_knot_trace.typ --root .
```

`WKCAND` coordinates are MetaPost units; divide by `72/25.4` to convert them
to millimetres. The final field reports output-space coordinates in millimetres.
`WKRAND` records the two candidate-only `uniformdeviate` bounds and returned
products immediately before the pair is shifted into `wKnot`; it is restricted
to the candidate assignment and leaves the existing `WKCAND` sequence intact.
`WKRANDFIX` encodes the same bound and product as exact 16.16 integers (two
base-256 digits per value) for arithmetic replay.

## M11 coastline lightness

The coast brush now uses the upstream `sphereAnglesToNormalVector` and
`normalVectorToLightness` law: it reconstructs the spherical normal from the
projected point's azimuth and radius, then applies the normalized source light
vector. At 600 ppi, globe ink coverage moves from 25.12% to 25.21% against
25.94% source, while the globe crop RMSE changes from 0.19545 to 0.19720 and
whole-plate RMSE from 0.12622 to 0.12662. This is a source-equation match with
a small raster-score regression; the remaining latitude width law and coast
random phase are still approximate.

Turning `_source-rounding` on for the production coast brush was tested by
itself. Against a same-checkout 600 ppi baseline, whole M11 RMSE regressed
`0.11295018 → 0.11302680` and globe crop RMSE regressed
`0.18989608 → 0.19019925`. Globe ink coverage moved slightly closer to source
(`26.35265% → 26.34078%` versus `25.94004%`); knot, eye, and refraction crops
were unchanged. The rounding toggle alone does not improve the coast image,
so it was reverted. The coast recursion still needs a source-matched width
and crossing model rather than a global rounding switch.

An isolated width-only quantization probe also failed the raster gate: rounding
the lightness-derived coast width to 16.16 while leaving recursion unchanged
moved whole M11 RMSE to `0.11298345` and globe RMSE to `0.19002779`. Globe ink
coverage moved closer (`26.35265% → 26.34438%`), but both errors increased, so
this narrower candidate was reverted too.

`instrument_m11_coasts.py` resets a counter around each source drawing stage.
On the pinned M11 input, MetaPost consumes 780 calls while constructing p1,
2676 for p2, then `[6, 15, 0, 3, 1, 0, 1, 1]` across the eight coastline
brushes. The current Typst latitude layers report 348 and 580 dash-stream
calls with their land/ocean masks. These are not yet equivalent counters:
Typst counts only its modeled dash calls, while the source wrapper counts every
`uniformdeviate`, including brush recursion and p2's randomized lightness
callback. This explains why a coast stream offset cannot yet be inferred from
the Typst layer counts; the source recursion and callback calls need porting or
tracing into the Typst RNG cursor first.

Using the known source prefix `780 + 2676 = 3456` as a shared Typst coast
stream offset did not improve the M11 globe crop: RMSE moved from `0.197196`
to `0.197208`, and ink coverage moved from `25.2125%` to `25.2113%` against
`25.9400%` source. Whole-plate RMSE also moved from `0.114834` to `0.114837`.
That candidate was reverted. It used the prior projection and open coastline
segments; re-evaluate stream alignment after the closed source coastline paths
and their recursive brush calls are ported.

After porting the source projection and closed, conflict-resolved coast paths,
the 3456-prefix experiment was repeated with one shared MetaPost stream passed
sequentially through the six visible coast brushes. It still did not improve
the source match: at 600 ppi whole M11 RMSE moved from `0.11268047` to
`0.11268452`, globe crop RMSE from `0.18874815` to `0.18876426`, and globe
ink coverage from `26.44278%` to `26.44952%` against `25.94004%`. The candidate
was reverted. A reliable coast phase still requires matching source brush
recursion calls per mass; advancing a Typst stream only by its modeled calls
does not reproduce those source boundaries.

### M11 coastline projection and outline topology

The pinned source's `pointOnGlobe` adds 90° to longitude, and
`horizonOnGlobe` treats negative values as visible. After converting the
upstream longitude sign, the previous Typst projection selected the opposite
hemisphere and its surface-mask longitude inverse was rotated. Updating the
projection and inverse to those source equations makes the visible landmass
set match: source and Typst both show landmasses 1, 2, 4, 5, 7, and 8. At
600 ppi, M11 whole RMSE falls from `0.114834` to `0.112687`; globe crop RMSE
falls from `0.197196` to `0.188772`. Globe ink coverage is now `26.439%`
against `25.940%` source, closer than the prior `25.213%`.

The coastline topology now follows `drawLandMass`: source calls
`thinBrushGenerate` once for each of eight closed paths (landmasses 3 and 6
are empty fallback paths), and Typst brushes one closed outline for each of
the same six visible masses. `instrument_m11_coast_paths.py` records both
projected path samples (`M11COAST`) and the source's conflict-resolved horizon
intervals (`M11ARC`). The Typst outline uses the source's five-step crossing
search, seam merge, ordered arc intervals and conflict rule. For example, the
six visible masses' source arc pairs are reproduced within 0.001 fullcircle
units. At 600 ppi globe crop RMSE falls from 0.188772 to 0.188748; ink is
26.443% versus 25.940% source. Whole M11 RMSE changes from 0.112687 to
0.112680. The raster gain is small, but the topology and arc order now follow
the source. Coast brush phase and recursive call counts remain open.

`diagnostics/m11_coast_brush_trace.typ` enables a private trace inside the
production `globe` coast loop. It records the exact width samples' recursive
outer/thin node tree and RNG cursor by source landmass ID. For the pinned M11
fixture, source versus Typst counts are:

| Landmass | Source RNG calls | Source recursion nodes | Typst RNG calls | Typst recursion nodes | Typst thin leaves |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 12 | 15 | 10 | 15 | 8 |
| 2 | 30 | 57 | 30 | 29 | 15 |
| 3 (empty) | 0 | 1 | — | — | — |
| 4 | 6 | 31 | 6 | 33 | 17 |
| 5 | 2 | 1 | 2 | 2 | 1 |
| 6 (empty) | 0 | 1 | — | — | — |
| 7 | 2 | 1 | 2 | 2 | 1 |
| 8 | 2 | 1 | 2 | 2 | 1 |

The corrected source trace counts all `uniformdeviate` calls inside each coast
brush; Typst's RNG cursor counts two values per dash pattern. The original
source regex missed `1/2uniformdeviate(d1)` because a digit before the function
name defeats a word-boundary match. After correcting it, the six visible paths
total 54 source calls versus 52 Typst calls; five mass vectors match exactly,
and mass 1 has one additional source dash (two calls). Source fallback paths 3
and 6 are empty, so Typst omits them. The earlier 106-versus-27 node summary
compared source recursion nodes to Typst dash leaves. Counting thin-stage
nodes gives 106 source recursion nodes and 80 Typst recursion nodes across the
six visible masses. `compare_m11_coast_brush.py` pairs nodes by parent and endpoint after
converting source bp to the Typst `(19,22)` mm globe frame. Across the six
trees it pairs 76 nodes; 69/76 recurse/stop decisions agree, and 66 pairs are
within 0.1 mm. Mass 2 accounts for the largest source tree (57 nodes, 29
Typst nodes): its first paired divergence is at depth 5. Source selects a
width cut at q time 3.95935, leaving 32.374/0.160 mm children; Typst finds no
cut for the corresponding node. The logged source q endpoint and cut level
both round to `0.15773` pt, while Typst's endpoint and target are both about
`0.0556478` mm. The q cubic controls are the one-third/two-third controls of a
straight `--` segment, so this case points to the near-endpoint behavior of
MetaPost `intersectiontimes`, not a missing curved width profile. The source
instrumenter now records exact 16.16 values as `integer:high-byte:low-byte`
triples. At the first M2 divergence, the target and endpoint width are both
`0:40:97` (0.15773010 pt). The q cubic width controls are
`0:41:114`, `0:41:23`, `0:40:188`, `0:40:97`; its x controls are
`238:78:10`, `242:7:112`, `245:192:214`, `249:122:60`. The forward hit is at
q time `3:245:152` (3.95935059) and x `249:5:249` (249.02333 bp); the reverse
ray has no hit. The cubic ends at q time 4, so MetaPost cuts about 0.160 mm
before the endpoint although the exact target equals its endpoint width. This
confirms a near-endpoint `firstIntersectionTimes` case. A reduced MetaPost
probe in `m11_coast_endpoint_intersection.mp` reproduces the behavior from that one
cubic plus the original template's ray bounds: exact endpoint target gives
`t=0.95935`; raising the target by one 16.16 unit moves the hit to `0.99634`,
and lowering it by one unit returns no hit. This isolates the behavior to
MetaPost's intersection routine and exact fixed-point inputs, independently of
the rest of the coastline traversal. The raw forward pair is
`(0.99014, 0.95935)` and the reverse-path pair is `(1, 0)`; Fiziko's wrapper
chooses the forward result. The first packet replay predicted
`(0.999996, 0.999996)` for this pair; after reproducing the source's
branch-dependent `three_l` tolerance updates, it now matches the forward and
reverse pairs exactly. A target-level sweep from eight 16.16 units below to
eight above the exact endpoint level reports no hit for offsets `-8…-1`,
`t=0.95935` at 0, and `t=0.99634` at +1. Offsets `+2…+8` return
`0.99268, 0.98901, 0.98535, 0.98169, 0.97803, 0.97437, 0.97070`.
This is a discontinuity in the fixed-point search, followed by hits tracking
the shallow cubic's near-endpoint root; it rejects a simple constant
parameter-margin model. The fixed-point replay now reproduces all 17 sweep
points exactly to one 16.16 time unit, including the no-hit and discontinuous
cases. It also reproduces every raw direct/reverse hit pair in the fresh S104
trace. The next step is to use this general source solver in production
`cutPathTime` sampling and measure its effect on complete recursion trees and
rasters; do not encode the sweep values as a coast-specific correction.
MetaPost's 2.11 source uses recursive cubic bisection and falls back to its
best approximate pair after 5000 unsuccessful backtracks
([pinned-version source](https://github.com/TeX-Live/texlive-source/blob/branch2025/texk/web2c/mplibdir/mp.w#L15053-L15102)).
Fresh paired traces confirm that recursive q splitting itself is exact:
`audit_m11_coast_q_children.py` checks all 28 recursive cuts on mass 2 and all
15 on mass 4. Every child endpoint matches the parent fixed-point cubic at
the recorded cut, and every child knot sequence matches the expected split.
Latitude globe coast brushes now build their initial q template from the
callback widths at source path times, round those widths to 16.16, and pass
the template through the fixed-point intersection solver. Against the same
code with this q template disabled, mass 4 improves from 4/5 to 30/31 paired
recursion decisions; mass 2's first branch endpoint residual falls from
0.48721 to 0.00280 mm, though its paired decision count remains 21/27. The
600 ppi M11 render improves slightly: whole RMSE `0.11289888 → 0.11289642`,
globe RMSE `0.18989648 → 0.18988674`, and knot RMSE is unchanged at
`0.05823034`. Keep the source q path enabled. Coast RNG calls remain 52
versus 54 source calls; masses 2 and 4 now have exact call vectors. The
remaining call difference is one mass-1 dash pattern, alongside the remaining
mass-2 recursion decisions.
Mass 4 has 31 source nodes and five
Typst nodes, with four of five paired decisions agreeing. The current trace
also logs each source normal and its lightness. For source mass 4's first
callback, the normal is
`(0.19894, -0.45815, 0.86633)` at `(16.91675, -38.96030)` MetaPost units;
the corresponding Typst coast sample uses the globe center `(19, 22)` mm and
diameter `30` mm, yielding a normalized vector within 0.001 per component.
This confirms the corrected radial factor `|point - center| / d`: `d` is the
diameter, matching the source's `abs(point) / 2s`. Typst's `calc.atan2` takes
`(x, y)`, so the source azimuth maps with `atan2(local.x, -local.y)`; the old
argument order put the normal in the wrong quadrant and underweighted the
coast. After correcting it, mass 4's root cut divides the 28.234 mm path into
14.296/13.938 mm children, close to source's 14.292/13.925 mm; mass 2's root
cut is 139.786/107.763 mm against source 139.59/107.88 mm. At 600 ppi,
globe ink coverage moves from `26.443%` to `26.353%` against `25.940%` source,
while globe RMSE changes from `0.188748` to `0.189896` and whole M11 RMSE from
`0.112661` to `0.112950`. Keep the source-equation match and record the raster
tradeoff. Mass 2 has 57 source recursion nodes and 29 Typst recursion nodes
(15 Typst thin leaves); pair its source cut parameters and width-cubic ranges
before changing dash phase or recursion further. A diagnostic-only variant reevaluated the analytic width
callback at recursive cut parameters instead of linearly interpolating sampled
widths. It changed thin nodes from 27 to 30 without changing the 52 modeled
calls, and regressed whole M11 RMSE `0.112950` → `0.113000` and globe RMSE
`0.189896` → `0.190092`; it was reverted.
Enabling the existing arc-based width interpolation on the coast call changed
some sampled widths but left the six recursion trees and all call counts
unchanged. Its 600 ppi whole/globe RMSE remained `0.11295018`/`0.18989608`,
identical to baseline, so the option was not retained.

A further production trial routed coast width crossings through the Typst
fixed-point `intersection-times` solver. The tree grew from 48 to 64 Typst
nodes against 106 source nodes; parent-aware recursion decisions agreed on
44/54 pairs versus 37/46 before. The 600 ppi render nevertheless regressed:
whole/globe RMSE changed from `0.11289878`/`0.18989608` to
`0.11291172`/`0.18994729`, while knot RMSE was unchanged. The solver hook was
removed. This confirms the coast divergence is not fixed by swapping only the
crossing search; the q-template controls and recursive subpath mapping still
need to match together.

The paired root cuts make that priority concrete. Upstream
`offsetPathTemplate` stores cumulative `arclength(subpath (0,i) of p)` in the
template's x coordinate and the width in y; `cutPathTime` chooses the width
crossing nearest the half-length x midpoint. It is therefore an arc-length
selection, not a screen-space x selection. On mass 4, both root lengths are
about 28.2 mm. Correcting the Typst normal angle moves its cut from the
incorrect `8.974/19.260` mm split to `14.296/13.938` mm, within 0.004/0.013 mm
of the source `14.292/13.925` mm. The source trace records a q cubic segment
around its hit at cumulative arc `40.51292 bp`:
`(40.37596, .15778)`, `(40.56644, .15770)`, `(40.75690, .15764)`,
`(40.94737, .15756)`, with target `.15773 bp`. The corrected mass 2 root
target now matches source (`.05272` vs `.05270` mm), although its deeper
recursive descendants remain different.
`instrument_brush.py` now emits `S101-CUBIC`, `S101-Q0`, `S101-QPOST`,
`S101-QPRE`, and `S101-Q1` records for the source q segment around each cut,
which should be paired with corresponding Typst descendants before
implementing source fixed-point cubic interpolation. A temporary screen-space x-midpoint
selector reduced whole M11 RMSE from `0.11266070` to `0.11264450` and globe
crop RMSE from `0.18874815` to `0.18868380`, but it interpreted q.x as page x;
the upstream definition proves q.x is cumulative arc length. That selector
was removed and its score is not evidence for a source-faithful change.

To extract and inspect the source path samples and Typst run counts inside the
Nix devshell:

```sh
mkdir -p /tmp/m11-coast-paths
python3 diagnostics/instrument_m11_coast_paths.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-coast-paths/fiziko.mp
cp comparisons/reference/main.mp /tmp/m11-coast-paths/main.mp
printf 'selected := 11; input main.mp;\n' > /tmp/m11-coast-paths/trace.mp
(cd /tmp/m11-coast-paths && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'M11COAST' /tmp/m11-coast-paths/trace.log
rg 'M11ARC' /tmp/m11-coast-paths/trace.log
nix develop path:./nix --command typst eval \
  'query(<m11-coast-geometry>).first().value' \
  --in diagnostics/m11_coast_geometry_trace.typ --root . \
  > /tmp/m11-coast-paths/typst.json
nix develop path:./nix --command python3 \
  diagnostics/compare_m11_coast_samples.py \
  /tmp/m11-coast-paths/trace.log /tmp/m11-coast-paths/typst.json
nix develop path:./nix --command python3 \
  diagnostics/compare_m11_coast_polyline.py \
  /tmp/m11-coast-paths/trace.log /tmp/m11-coast-paths/typst.json
```

`compare_m11_coast_polyline.py` measures each source sample to the nearest
Typst outline segment, so cyclic starts and different point densities do not
inflate the geometric residual. On a fresh paired trace, the six visible
masses have median errors `0.000046–0.000087 mm` and maximum errors
`0.000140–0.004568 mm`. This rules out the projected centerline outline as
the main cause of the recursive tree mismatch. Vertex-only nearest-neighbor
statistics from `compare_m11_coast_samples.py` are useful for locating run
ordering, but should not be read as path-shape error when sample densities
differ.

The sample pairing confirms that source and Typst use different cyclic start
positions for the closed coastline, while their raw visible runs can still be
paired in source traversal order. For mass 1, the first source sample maps to
Typst run 1, point 1 within `0.000126 mm`; source samples first reach runs 1
then 0. This supports treating the root endpoint difference as a cyclic seam
choice, not as evidence that the projected coastline itself is displaced.
Nearest-sample errors across all masses are not a shape score: source samples
cover hidden coast portions too, and Typst's points are sparse run vertices.
The analyzer is a seam/order diagnostic only. The brush still needs to carry
the source q template and recursive subpath parameterization together.
Comparing the source path's first traced point with the assembled Typst outline
locates it at outline index 1 for masses 1, 2, and 4 (within `0.000058` to
`0.000126 mm`); for masses 5, 7, and 8 it maps to index 0 (within
`0.000087` to `0.000140 mm`). In the first three cases outline index 0 is
exactly on the 15 mm horizon. A production trial rotated those closed paths to
index 1. The 600 ppi M11 metrics and all six per-mass recursion node arrays,
width samples, and RNG call counts were unchanged, so the production rotation
were exactly unchanged against the saved baseline: full/globe/knot RMSE
`0.11289878/0.18989608/0.05823034`, with per-mass calls
`10/30/6/2/2/2`. The production rotation was reverted. The source seam is
geometrically present already; this cyclic reindexing does not resolve the
recursive q-template mismatch.

To compare source recursion nodes and random calls by landmass, layer the
generic brush instrumenter with the M11 coast counter and evaluate the
production Typst trace:

```sh
mkdir -p /tmp/m11-coast-brush
python3 diagnostics/instrument_brush.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-coast-brush/brush.mp
python3 diagnostics/instrument_m11_coasts.py \
  /tmp/m11-coast-brush/brush.mp /tmp/m11-coast-brush/fiziko.mp
cp comparisons/reference/main.mp /tmp/m11-coast-brush/main.mp
printf 'selected := 11; input main.mp;\n' > /tmp/m11-coast-brush/trace.mp
(cd /tmp/m11-coast-brush && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
typst eval 'query(<m11-coast-brush-trace>).first().value' \
  --in diagnostics/m11_coast_brush_trace.typ --root . \
  > /tmp/m11-coast-brush/typst.json
nix develop path:./nix --command python3 diagnostics/compare_m11_coast_brush.py \
  /tmp/m11-coast-brush/trace.log /tmp/m11-coast-brush/typst.json 2
nix develop path:./nix --command python3 diagnostics/compare_m11_coast_brush.py \
  /tmp/m11-coast-brush/trace.log /tmp/m11-coast-brush/typst.json 1
```

Landmass 1's first paired divergence is a useful complementary case to
landmass 2's near-endpoint hit: its target equals the starting width, yet the
source width-template cubic returns an interior cut at path time 0.18750.
The comparison records that cut and the resulting 0.203 mm child, while
Typst reports no crossing. See the M11 coast item in
[`comparisons/fidelity-plan.md`](../comparisons/fidelity-plan.md) for the
measured pairing and rejected production trial.

The dash-path hook now records source leaf endpoints as well as pattern width
and length. On mass 1, the sixth source dash is a 1.68953 bp (0.59603 mm)
leaf from approximately `(23.06729, 7.56214)` to `(23.20318, 7.62602)` mm.
The nearby Typst seam has a 0.14086 mm dashed tail and 0.16866/0.22203 mm
non-dashed leaves; their endpoints lie within about 0.03 mm of the source
leaf, but their path lengths are distributed differently. This localizes the
two-call deficit to the seam's recursive path geometry/parameterization, rather
than a missing coast-level RNG call. The hook is gated by `traceCoastWidth`,
so it adds records only during the instrumented M11 coast stage.

Increasing only the geographic input densification (`coast-step: 1` instead
of `0`) does not repair this seam. On mass 1 it changes the thin tree from 15
to 21 nodes, leaves 14/15 paired decisions agreeing, and increases root
endpoint error from 0.37242 to 0.36701 mm only marginally. The extra samples
change other source path-time intervals as well, so this candidate was
discarded without a render trial. Keep `coast-step: 0` for source-parity work;
the remaining issue is local recursive parameterization, not insufficient
geographic sampling density.

To capture these records, run `instrument_brush.py` before
`instrument_m11_coasts.py` as in the coast recursion command above, then
inspect `S101-DASHPATH` and `S101-DASH` records between
`M11-COAST-BEGIN 1` and `M11-COAST-END 1`.

To compare one recursive source q-template node's knots with the original
Typst coast samples, run:

```sh
nix develop path:./nix --command python3 \
  diagnostics/compare_m11_coast_qknots.py \
  /tmp/m11-coast-brush/trace.log /tmp/m11-coast-brush/typst.json 1 2
```

The generated child endpoints need not coincide with original input samples;
the diagnostic reports those separately from matched intermediate knots.
It also reports signed source-minus-Typst q.x (cumulative-arc) deltas. Among
matched knots, M1 depth 2 averages `-0.37381 mm` with at most `0.00034 mm`
deviation; M2 depth 2 averages `-0.16806 mm` with at most `0.00064 mm`
deviation. Their position/width errors remain below `0.00053/0.0000063 mm`.
These nearly constant offsets are consistent with different closed-path arc
origins; translating all q.x values does not change a midpoint intersection.
M2 depth 1 has a wider `0.02264 mm` deviation, so this interpretation is
limited to the deeper matched spans. Keep the next probe focused on mapping q
cut times onto the child centerline path.

For exact recursive-state verification, the same source trace now records the
16.16 q-path knots, the four cubic controls around each selected cut, and its
16.16 cut time. Run:

```sh
nix develop path:./nix --command python3 \
  diagnostics/audit_m11_coast_q_children.py \
  /tmp/m11-coast-brush/trace.log 1
nix develop path:./nix --command python3 \
  diagnostics/audit_m11_coast_q_children.py \
  /tmp/m11-coast-brush/trace.log 2
```

The audit replays each q cubic split with fixed-point de Casteljau arithmetic,
then compares both child endpoints and the complete child knot sequences to
the corresponding parent subpaths. It checks all 7 mass-1 cuts and 28 mass-2
cuts: every child knot sequence matches exactly, with zero 16.16-unit endpoint
error. This proves the pinned source carries the sliced q state exactly
through recursion; the remaining production divergence is in Typst's q/path
state, not source subpath construction.

A rejected coast prototype built a 16.16 width grid at integer source path
times by evaluating Typst's analytic lightness-width callback at the
corresponding interpolated arc fractions, then made straight q cubics from
those samples. It did not reproduce the source recursion: landmass 1 had
15/11 source/Typst nodes, 9/11 paired decisions, and a 0.372 mm paired-root
error; landmass 2 had 57/97 nodes, 29/35 paired decisions, and a 0.168 mm
root error. No full-render trial was warranted. The grid reconstructed width
values but did not establish the source q-template's recursive path-time and
arc mapping, so it was removed from the production coast call. Preserve the
source q cubics and their child parameter maps together before retrying this
integration.

The same trace exposed three identical consecutive source q knots at one
M1 contour point. `_globe-land-outline-data` had deduplicated the matching
centerline vertices but kept advancing path time, leaving a 108→110 gap; a
time-109 lookup then interpolated between different points. It now preserves
duplicate vertices inside a coast run and still merges shared coast/horizon
joins. The M1 input path grows from 155 to 156 points, and the threshold-level
width at the first paired depth-2 node now matches the source. M1's recursion
counts and 10 modeled calls are unchanged; other visible landmasses' path and
width traces are identical. At 600 ppi, whole/globe RMSE changes only from
`0.11289878/0.18989608` to `0.11289888/0.18989648`, with the other M11 crops
pixel-identical. Keep the time-label correction, while continuing to trace
the remaining q cut and centerline child mapping.
Re-enabling the integer-time q-grid after this correction still leaves M1 at
15/11 source/Typst nodes (9/11 paired decisions) and M2 at 57/97 nodes
(29/35 paired decisions). The candidate's depth-2 q array remains one knot
short (24 versus 25 source knots), so restoring the repeated centerline point
does not by itself reconstruct the source q subpath. The q-grid hook was
removed again; the remaining mismatch is in q-state generation/splitting,
not just the omitted source-time label.

The instrumented source also emits `S101-CUTINPUT`, `S101-RAY1/2-FIX`,
`S101-HIT1/2`, `S101-QCTRLPT-FIX`, and `S101-CUTFIX` records, alongside the
separate decimal `S101-QX1/QY1` or `S101-QX2/QY2` ray-control records.
They contain the exact 16.16 midpoint, target, selected hit, ray controls, and
width-template cubic controls. The mass-1 start-width case is replayed in
`metapost_intersection_sweep.typ`; the fixed-point solver returns the same
selected hit as MetaPost. This separates intersection-search parity from the
remaining production gap: carrying the cubic width template through
recursive Typst brush paths.

To reproduce the reduced endpoint probe:

```sh
mkdir -p /tmp/m11-endpoint-probe
cp original/fiziko.mp diagnostics/m11_coast_endpoint_intersection.mp \
  /tmp/m11-endpoint-probe/
nix develop path:./nix --command bash -c \
  'cd /tmp/m11-endpoint-probe && mpost -interaction=nonstopmode \
    -halt-on-error -jobname=probe m11_coast_endpoint_intersection.mp'
rg '(EXACT|ABOVE|BELOW|SWEEP) ' /tmp/m11-endpoint-probe/probe.log
```

The full ±8-unit sweep shows a non-monotone transition: −8 through −1 return
no hit, 0 returns `0.95935`, +1 jumps to `0.99634`, +2 returns `0.99268`, and
the remaining positive levels move gradually back along the shallow cubic
root. This rules out a fixed endpoint margin and a monotone one-unit fallback;
the low-level search order/state must be reproduced before changing coast
recursion.

The source transcript brackets each coast brush with `M11-COAST-BEGIN` and
`M11-COAST-END`; count `S101 NODE` and `S101-CUBIC` markers only inside those
brackets. Source RNG draws are the corresponding `M11-COAST` values. The
Typst metadata stores `landmass`, `calls`, `outer`, `thin`, and the complete
recursive `nodes`.

To reproduce the source stage counts and the Typst layer counts inside the
Nix devshell:

```sh
mkdir -p /tmp/m11-coast-trace
python3 diagnostics/instrument_m11_coasts.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-coast-trace/fiziko.mp
cp comparisons/reference/main.mp /tmp/m11-coast-trace/main.mp
printf 'selected := 11; input main.mp;\n' > /tmp/m11-coast-trace/trace.mp
(cd /tmp/m11-coast-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'M11-(P1|P2|COAST)' /tmp/m11-coast-trace/trace.log
typst eval 'query(<m11-coast-rng>).first().value' \
  --in diagnostics/m11_coast_rng_trace.typ --root .
```

## M11 source knot paths and layer intervals

The M11 fixture's original sine samples did not reproduce the actual curves in
the pinned MetaPost source: MetaPost interpolates the 25 anchor points with its
own path solver. Sampling each source path every 1/4 path-time and storing the
result in `comparisons/m11-knot-paths.typ` lowered 600 ppi knot crop RMSE from
0.14230 to 0.06233. A 1/8-step path (193 samples per strand) lowered knot RMSE
to 0.05979 and whole-plate RMSE from 0.11513 to 0.11490. The 1/16-step path
(385 samples per strand) lowers them further to 0.05904 and 0.11483. It raises
the comparison runtime from 28.6 s to 41.6 s, a cost retained for the measured
fidelity gain. Globe, eye, and refraction crops are unchanged. `comparisons/run.py`
includes this data file in the isolated input snapshot so the comparison
remains reproducible.

A 1/32-step (769-point) candidate regressed knot RMSE to 0.05925 and whole-plate
RMSE to 0.11485 while increasing Typst render time from 36.3 s to 96.3 s. The
denser sample was discarded; 1/16 remains the best measured source-curve grid.

Regenerate the sample data from the pinned driver inside the Nix devshell:

```sh
mkdir -p /tmp/m11-path-source
python3 diagnostics/instrument_m11_knot_paths.py \
  comparisons/reference/main.mp /tmp/m11-path-source/main.mp 16
cp "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-path-source/fiziko.mp
printf 'selected := 11; input main.mp;\n' > /tmp/m11-path-source/trace.mp
(cd /tmp/m11-path-source && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
python3 diagnostics/extract_m11_knot_paths.py \
  /tmp/m11-path-source/trace.log comparisons/m11-knot-paths.typ
```

Tube mask mode now follows `knotFromStrands`' interval construction: each
strand is split halfway between adjacent crossings, the supplied per-crossing
layer value is assigned to that interval, and higher-layer tube silhouettes
erase earlier ink before their own hatch is drawn. `path-times:` maps sample
positions onto source curve parameters, so these source-derived points place
the mask boundaries in the same parameter space. Knot ink coverage is 2.253%
versus 2.606% in the source. Crossing positions still use sampled line
segments, and the erasing silhouette remains a width-stroke approximation.

An intersection audit of the pinned `knotFromStrands` source found three
unique M11 crossings at path times 6, 12, and 18 on both strands. The source
logs duplicate each crossing while scanning overlapping 1/4-time windows, then
`appendList` deduplicates the rounded 0.1-time values. The current 1/16 Typst
polyline detector finds the same three rounded times and positions at
(94,22), (102,22), and (110,22) mm. The unrounded source intersections differ
from those points by at most 0.0006 mm, so additional time quantization or
denser path sampling would not improve these crossings. Mask drawing now
erases the accumulated lower layer with all silhouettes in the next layer
before drawing any hatch in that layer, matching source `layerPicture`; this
does not change the current M11 pixel hash. A filled polygon mask built from
sampled offset frames was also compared; knot RMSE regressed from 0.05904 to
0.06818 and whole M11 RMSE from 0.11268 to 0.11355, so it was reverted. The
source `tubeOutline` offset geometry was then traced directly. Replacing the
white-stroke eraser with the six exact traced source outlines changed knot
RMSE only from 0.05904362 to 0.05903513 and whole-plate RMSE from 0.11268047
to 0.11267972; knot coverage changed from 2.29031% to 2.29052% (source:
2.60589%). The oracle was removed. The offset geometry is a small part of
this fixture's raster difference; hatch placement and coverage remain larger
gaps.

The pinned source's `q2` and `q3` tube boundaries are now sampled at 1/16
path-time intervals and paired against the corresponding Typst boundary lanes.
Across the six segments, mean point error is 0.00051–0.00117 mm (maximum
0.0179–0.0374 mm); mean tangent error is 0.041–0.104 degrees. Their centerline
endpoints match exactly. These measurements rule out a broad offset-boundary
error as the cause of the remaining brush-call mismatch. The source trace now
also records all three inputs to `tubeAnglesToNormalVector`, its output
normal/lightness values, and shadow hits. The Typst trace retains each lane's
radial coordinate and sampled points, widths and lightness. Do not tune the
shade law from raw width values: they also include source residual-width and
lane-parity factors.

A production probe rebuilt each `strand-knot` interval from its enclosing
source cubic controls before passing the path to `tube`. For the six existing
M11 intervals, the reconstructed samples differed from direct source-path
slicing by at most `0.000021 mm`; all interval endpoints already align with
the source cubic grid. The 600 ppi comparison regressed knot RMSE from
`0.05823034` to `0.05949298` and whole-plate RMSE from `0.11289878` to
`0.11300959`. The production hook and its temporary diagnostic were removed;
the general source path-time splice replay remains separate from this trial.

For source call 2, lane 6, 37 source lightness samples pair to Typst lane 1
within 0.0021 mm mean distance (0.0188 mm maximum). The current Typst shade
averages 0.220 absolute error against the source values; flipping the radial
y component in a trial formula reduces that to 0.00072 (0.00961 maximum).
However, that formula trial regresses 600 ppi RMSE: M11 knot `0.05895 →
0.07697`, M4 whole plate `0.07109 → 0.12625`, and M6 whole plate
`0.08919 → 0.11594`. It was reverted. The source angle mapping itself is
close: source alpha differs from `asin(u)` by 8.8e-6 rad on average, the center
tangent angle differs by 0.0051 rad, and both sides have zero radius slope.
For even source k=6, no parity width factor applies. Source width averages
0.01996 mm (maximum 0.04525 mm), while Typst's current profile averages
0.04315 mm (maximum 0.05493 mm); the first paired width is 0.00227 mm versus
0.01866 mm. The pointwise formula trial corrected the measured source widths
and moved the six per-segment absolute call-count error from 64 to 20: current
Typst calls in source order are `10/38/40/52/50/14`, while the candidate gives
`14/52/50/40/38/10` against source `14/58/54/42/38/18`. The total remains 204
versus 224. Despite the closer call distribution, the candidate worsened the
render, so keep it reverted until the y-axis/light-direction transform and
thin-brush dash placement are reconciled. The diagnostic now reports
`candidate-calls` and `candidate-edge-calls` without changing drawing output.
Those call-count totals predate source-rounded edge paths; the corrected totals
and lane-by-lane tree traces below supersede them.

The target k=6 lane's source trace contains 19 thin-brush dash leaves; the
current Typst lane has 5. An earlier source-normal width diagnostic produced
17 leaves and appeared to merge two source intervals, but it called
`_ink-loops` with `source-rounding: false`, unlike the production tube path.
With production 16.16 rounding enabled, the source-normal diagnostic produces
19 leaves and 38 random calls, matching the source lane's 19 leaves and 38
calls. Projecting the source and Typst leaf endpoints onto the same sampled
lane gives 0.00364 mm mean and 0.01194 mm maximum arc-position error; maximum
geometric projection error is 0.00134 mm. The two restarts near arc positions
17.894 and 18.780 mm are present in both traces. Reproduce this focused result
after generating the source and Typst traces above with:

```sh
nix develop path:./nix --command python3 diagnostics/compare_m11_knot_dashes.py \
  /tmp/m11-tube-outline-trace/trace.log /tmp/m11-knot-tube-trace.json \
  --candidate
```

This resolves the lane-level phase-pairing discrepancy in the rounded
diagnostic. The earlier broader source-normal trial was rejected because its
comparison treated `M11WIDTHFIX` as the complete lane width. That trace records
only `maxShadingStrokeWidth * lightness`; the source applies an additional
residual multiplier on odd lanes. The all-lane comparison below includes that
factor and supersedes the earlier call-distribution conclusion. Earlier
pre-cubic traces attributed the apparent gaps to a 0.02009 rad tangent error;
the retained `source-cubic-step: 4` model resolves that tangent discrepancy.
The source cubic controls for both `currentTubePath` and k=6 `currentPath` (36
segments each) remain available for exact sample pairing.

Replaying that trace and differentiating the cubic controls of
`currentTubePath` at the 37 k=6 width samples reproduces the source
`tubeAnglesToNormalVector` path angle with `3.1e-5` rad mean error and
`9.5e-5` rad maximum error. A fourth-order derivative of the unoffset 1/16
strand samples is still off by `0.0134` rad at the known t=20 width trough.
The target tangent is therefore the cubic midpoint path formed after the two
offset boundaries are generated, not just a smoother derivative of the input
strand. Reconstructing each cubic from five equally spaced samples over four
input intervals matches the traced midpoint controls within 0.000049 mm and
the source tangent within 0.000156 rad maximum (0.000033 rad mean). Enabling
`source-cubic-step: 4` for M11 lowers 600 ppi knot RMSE from 0.058950 to
0.058819 and whole-plate RMSE from 0.112672 to 0.112661. Ink coverage remains
2.843% against 2.606% source; the corrected source-rounded lane diagnostic
counts 212 calls against 224 source calls, so the
two short dash-phase restarts remain open.

The regenerated post-cubic trace pairs source call 2, lane k=6 to Typst's
strand 0, interval 0, `u=0.5` lane within 0.000039 mm mean point error. At its
37 matched samples, flipping the vertical component in the Typst cross-section
normal gives source-normal error 0.000055 mean and 0.000127 maximum; the old
sign gives 0.573 mean and 0.983 maximum. Applying that correction only to
`u=0.5` lanes moves this lane from 10 to 34 calls (source: 38), but across all
six intervals raises total calls from 202 to 240 (source: 224) and worsens the
per-interval distribution. This diagnostic used the unadjusted `M11WIDTHFIX`
value as the target on odd lanes. The source residual was not applied in that
comparison, so its call totals do not measure the source width law. The
all-lane residual-corrected trace below replaces that conclusion.

### M11 self-shadow geometry in tube lighting

The source trace records the complete six `tubeOutline` contours plus the
shadow plane depth and light vector. Rebuilding each contour from the paired
Typst tube path agrees with source to `0.0004 mm` mean distance or better.
Projecting the source upper-layer contours with the recorded depth and light
vector reproduces every sampled shadow decision for lower calls 4–6: precision
and recall are both `1.0` across 63, 49, and 42 shadowed samples respectively.
The trace-backed checker is:

```sh
nix develop path:./nix --command typst query diagnostics/m11_knot_tube_trace.typ \
  '<m11-knot-tube-trace>' --field value --root . \
  > build/m11-knot-tube-trace-shadow.json
nix develop path:./nix --command python diagnostics/compare_m11_shadow_polygons.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace-shadow.json
```

Production tube lighting receives only higher-layer contours that intersect
the current strand, matching the source's `intersectiontimes` precondition;
its shadow depth is `1.5 * current segment width`. The all-lane diagnostic
matches source call k to Typst inner lane `7-k` (and k=0/8 to the opposite
edges). It applies the source odd-lane residual
`abs(tubeWidth/bw1 - lineDensity/2) / bp` to `M11WIDTHFIX` before comparing
effective widths, using source shadow labels that the polygon audit below
reproduces at precision and recall `1.0`. With that correction,
source-normal plus source-shadow candidate width MAE is `0.00000–0.00165 mm`
by tube call, versus
`0.01149–0.01545 mm` for the old normal. The production `strand-knot` tube
renderer now uses the source radial normal sign and actual shadow contours.

The full `tube()` replay with the shared MetaPost stream and source segment
order gives per-call brush counts `14/54/54/42/38/16` (218 total) against
source `14/58/54/42/38/18` (224 total), for per-call L1 error 6. The source
order is strand 1 then strand 0 within each rank; `strand-knot` now uses that
order when caching and painting layer segments. This ordering lowers the 600
ppi M11 knot crop RMSE from `0.07923` to `0.07841` and whole-plate RMSE from
`0.11503` to `0.11493`. M4 and M6 use standalone tube lighting and remain at
`0.05947` and `0.08949`. The next gap is the remaining six brush calls, on
source calls 2 and 6, plus their resulting dash placement.

Refreshing `m11-shadow-brush-inputs.typ` from the same source log and replaying
those lanes through the current `_ink-loops` confirms that the brush recursion
can reproduce both outstanding source calls when given the traced post-shadow
center paths, integer width callbacks, q controls, and RNG offsets. Call 2
matches all three active lanes exactly (`12/38/8` calls); call 6 also matches
all active lanes (`6/0/12`). The production `tube()` replay remains short by
four calls on call 2 and two on call 6. This narrows the open work to building
the same source q state and parameter mapping from production tube geometry;
the exact-input replay is diagnostic evidence, not a production fix.

Generate the complete lane report with:

```sh
nix develop path:./nix --command typst query diagnostics/m11_knot_tube_trace.typ \
  '<m11-knot-tube-trace>' --field value --root . \
  > build/m11-knot-tube-trace-source-light.json
nix develop path:./nix --command python diagnostics/compare_m11_all_shading_samples.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace-source-light.json
nix develop path:./nix --command typst query diagnostics/m11_shared_rng_order_trace.typ \
  '<m11-shared-rng-order>' --field value --root . \
  > build/m11-shared-rng-order.json
nix develop path:./nix --command python diagnostics/compare_m11_shared_rng_order.py \
  /tmp/m11-q-audit/trace.log build/m11-shared-rng-order.json
```

### M11 knot tube lanes and shared RNG

The source trace starts the knot at MetaPost random-call offset 4639. Its six
visible tube segments draw in rank order `+1` then `-1`, with local brush-call
counts 14, 58, 54, 42, 38 and 18 (224 total). Before enabling
`source-cubic-step: 4`, the Typst source-derived tube renderer included both
boundary lanes and drew hatch marks before the two thin outline paths; its
modeled calls totaled 204. The current source-cubic candidate consumes 212
calls with source-rounded boundary recursion, so the shared stream still
differs. (The source draw-order vector is
`j2,j4,j6,j1,j3,j5`; the values above follow that order.)

`strand-knot(..., rng: "metapost", rng-offset: 4639)` precomputes the tube
segments in source draw order using one shared stream, then composites their
cached drawings in the existing low-to-high mask order. On the exact 600 ppi
M11 comparison, the corrected rank-deduplicated shared stream changes the
boundary-lane candidate's whole-plate RMSE from `0.11267309` to `0.11267222`
and knot crop RMSE from `0.05895999` to `0.05895004`. Knot ink coverage is
`2.8427%` versus `2.6059%` in the source; the shared stream does not solve the
remaining over-coverage. M11 globe crop is unchanged at `0.18874815`. The
pixel gain is small, but the source draw order is now represented directly;
the 20-call deficit and cross-plate lane tradeoffs remain open. With the
source-order boundary lanes, M4 changes from 0.060190 to 0.060176 RMSE, while
M6 changes from 0.089190 to 0.089493 and its ink rises from 2.3327% to
2.4854% (source 2.3327%). This is a real variable-radius counterexample; the
boundary model needs refinement before claiming a general tube improvement.
The first uncorrected rank-duplicate run was discarded. Reproduce with:

```sh
nix develop path:./nix --command ./compare.sh --case M11 --mode nominal \
  --ppi 600 --output build/m11-shared-rng-dedup
```

A mask-shape trial replaced the knot's white thick-centerline erasure with a
closed polygon sampled from the centerline normals and radius. On the same
600 ppi M11 comparison, whole-plate RMSE worsened from `0.112899` to
`0.113991` and knot crop RMSE from `0.058230` to `0.069732`; the candidate was
reverted. The source silhouette comes from `offsetPathGenerate` boundaries,
so normal-offset samples do not preserve its joins and end geometry.

Regenerate the source crossing trace inside the Nix devshell:

```sh
mkdir -p /tmp/m11-knot-crossings
python3 diagnostics/instrument_m11_knot_crossings.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-knot-crossings/fiziko.mp
cp comparisons/reference/main.mp /tmp/m11-knot-crossings/main.mp
printf 'selected := 11; input main.mp;\n' > /tmp/m11-knot-crossings/trace.mp
(cd /tmp/m11-knot-crossings && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'M11X' /tmp/m11-knot-crossings/trace.log
typst eval 'query(<m11-knot-crossings>).first().value' \
  --in diagnostics/m11_knot_crossing_trace.typ --root .
```

The source outlines are the closed paths `q3 -- reverse(q2) -- cycle` after
`tube` applies `offsetPathGenerate` to an 1/8-subdivided centerline. Trace the
six visible outlines and their centerline intervals with:

```sh
mkdir -p /tmp/m11-tube-outline-trace
python3 diagnostics/instrument_m11_tube_outlines.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m11-tube-outline-trace/fiziko.mp
cp comparisons/reference/main.mp /tmp/m11-tube-outline-trace/main.mp
printf 'selected := 11; input main.mp;\n' \
  > /tmp/m11-tube-outline-trace/trace.mp
(cd /tmp/m11-tube-outline-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg '^M11TS|^M11TO|^M11EDGE|^M11EDGECURVE|^M11CENTER[AB]|^M11CURVE|^M11POST|^M11CUT|^M11ANGLE|^M11WIDTHINPUT|^M11LIGHT|^M11WIDTHFIX|^M11SHADOW|^M11THIN|^M11THINCALC|^M11BQPT|^M11BRCUT|^M11QPT|^M11THINPATH|^M11TCUT|^M11TCUTFIX|^M11TCUTPATH|^M11DASH' \
  /tmp/m11-tube-outline-trace/trace.log
python3 diagnostics/extract_m11_tube_outlines.py \
  /tmp/m11-tube-outline-trace/trace.log \
  /tmp/m11-tube-outline-trace/outlines.typ
typst eval 'query(<m11-knot-tube-trace>).first().value' \
  --in diagnostics/m11_knot_tube_trace.typ --root . \
  > /tmp/m11-knot-tube-trace.json
```

The midpoint and boundary cubic controls are split into paired `A`/`B` log
records (`M11CENTERA/B`, `M11EDGECURVEA/B`) so MetaPost does not wrap their
coordinates across transcript lines. Join records by call and curve index
before comparing controls. `M11CURVEA/B` records do the same for source lanes
k=2, 6, and 8; `M11PARAM` records list the current lane, centerline, and
`tubeWidth` path lengths. `M11POSTPARAM` and `M11POSTCURVEA/B` capture each
lane after `shadowCut`, immediately before `brushGenerate`. `M11CUTSHADOW`
records lane depth, occluder depth, and light vector for each shifted shadow;
`M11CUT` records each intersection's lane time, shadow-path time, and the
current path lengths before the cut.

The six source midpoint paths pair to the reconstructed Typst cubics with
control-point MAE of 0.000010–0.000013 mm and maximum error below 0.000055 mm.
Source lane controls also fit the paired Typst sampled paths within 0.002 mm.
Before `shadowCut`, each traced lane, centerline, and `tubeWidth` path has 24
or 36 units in a given call. `shadowCut` then changes calls 4–6 lane lengths
to 39–41, 39–40, and 28 units respectively; calls 1–3 remain unchanged. The
brush callback times reach these post-cut path ends. The `..` join appears to
preserve the original curve geometry while inserting path knots: for two call
4 cuts, the post-cut connector cubics match the original de Casteljau subcurves
within `3.8e-6` and `1.7e-5` mm. The callback mismatch is therefore a knot/time
mapping difference, not evidence that source skips the hidden strokes. Typst
does not insert these knots before brush recursion. Use `M11POSTCURVEA/B` to
compare the reparameterized path; do not tune lighting from the uncut path
comparison alone.

`analyze_m11_shadow_callbacks.py` pairs each pre/post path length with the
integer `offsetPathTime` callback samples (`M11WIDTHINPUT`/`M11LIGHT`). On all
nine expanded call-4–6 lanes, the post-cut path extends 3–5 time units past
the original centerline, and every extra lightness and normal sample matches
the original endpoint at the trace's five-decimal precision. This is
consistent with the callback lookups clamping on the original centerline and
width paths, though the rounded trace cannot establish exact equality. Run it
on the trace above:

```sh
nix develop path:./nix --command python \
  diagnostics/analyze_m11_shadow_callbacks.py \
  /tmp/m11-tube-outline-trace/trace.log
```

The analyzer also follows each successful `M11CUT` record to the next
intersection attempt and models `..` as a one-segment connector between the
surviving path pieces. It stores each current cubic segment's interval in the
original path-time domain, splits those intervals at `cut ± 0.05`, and
replaces the removed intervals with one connector. Across 60 successful cuts,
53 add two path-time units and seven add one. The one-unit changes occur when
the removed interval crosses an integer path-time knot, replacing two source
cubic segments with a prefix, connector, and suffix. This per-segment model
matches every next-attempt and terminal path length on all 27 traced lanes,
and all nine `M11POSTPARAM` lengths. It also maps call 4/lane 2's later cut at
`28.06259` back to original path time `26.06259`, agreeing with the
independently reconstructed geometric hit at `26.0622` within trace rounding.
The interval splice and source-time lookup are ported to Typst as
`_source-path-time-splice` and `_source-path-time-at`. Replay every cut and
terminal path length from a fresh source trace with:

```sh
nix develop path:./nix --command python \
  diagnostics/extract_m11_shadow_splice_cases.py \
  /tmp/m11-tube-outline-trace/trace.log build/m11-shadow-splice-cases.typ
nix develop path:./nix --command typst eval \
  'query(<m11-shadow-splice-replay>).first().value' \
  --in diagnostics/m11_shadow_splice_replay.typ --root .
```

The Typst replay matches 60/60 post-cut lengths and 27/27 terminal lengths.
This ports the path-time structure only; it does not yet replace the connector
geometry or alter production `strand-knot` rendering.

The instrumenter also emits `M11WIDTHFIX` as two base-256 digits. These encode
the raw source 16.16 MetaPost bp value of
`maxShadingStrokeWidth * lightness`; the extractor converts it to millimetres
only after decoding. This preserves the source fixed-point grid without asking
MetaPost to represent the overflowing intermediate `value * 65536`. Across
1,895 callback samples, the decoded width differs from the product of the
five-decimal log values by at most `5.76e-6 mm` (mean `2.22e-6 mm`). Replaying
these widths leaves the same 15/18 lane call totals and the same three
mismatches. The width log precision therefore does not explain those brush-tree
differences. In the regenerated trace, all 15,963 shared M11 marker lines match
the earlier trace exactly; the new trace additionally contains the width and
recursive-path markers.

`M11THINPATH` and `M11TCUTPATH` now record source recursive-node endpoints and
valid cut coordinates. Parent-aware pairing isolates the extra call-4/lane-2
dash to a branch boundary. Source splits the segment from `(89.05132,15.94174)`
to `(90.18163,15.57985)` at width `0.03807`, near `(89.32121,15.79910)`.
That leaves two adjacent source pieces of `0.30544` and `0.31416` mm, both
below the minimum dash length. Typst chooses width `0.041` and cuts near
`(89.615,15.686)`, leaving one `0.61732` mm dash and consuming two extra RNG
values. The enclosing geometry endpoints pair within about `0.004` mm, but a
small width-range difference (`0.03513` vs `0.03515`) moves the midpoint over
a source dash-width step. This is the first concrete branch-level cause; it
still needs a source-equivalent width-template/cut rule before a production
change is justified. Sampling at 16 and 32 points per cubic leaves the three
known lane call totals unchanged. Supplying source cumulative arc positions
also leaves those three totals unchanged and worsens other traced lanes, so
that trial was removed.

The latest source probe adds `M11THINCALC` fixed-point operands and
`M11QPT` two-dimensional control points for the divergent call 4/lane 2,
call 4/lane 6, and call 5/lane 2 knot lanes. For the split that
produces the `0.03513` mm endpoint, source `cutPathTime` uses target `0.03514` at path time
`3.99158`; the child begins at `0.03513` after the cut. The q-template is a
sequence of MetaPost `--` cubics whose controls are quantized to 16.16 bp. For
example, one segment records raw coordinates `(22:14, 23:53, 24:91, 25:130)`
as integer:low-byte pairs. Recursive `subpath` operations preserve the sliced
cubic controls. The current replay instead linearly interpolates callback
widths again at each cut. Quantizing the replay's path-time cut and modeling a
fresh cubic from each densified sample-width pair both leave the 15/18 call
match unchanged; the latter moves the endpoint farther from source. The next
useful model must carry and split the original fixed-point q cubics through
recursion.
An opt-in replay candidate evaluated a fresh cubic from the original integer
callback widths at each source path time. It regressed the lane match from
15/18 to 14/18, adding a call-6/lane-8 mismatch. This reconstruction ignores
the q controls already sliced by `brushGenerate` before thin recursion, so the
candidate was removed without a render trial. `M11QPT` now records those
entry controls, and `M11TCUTFIX` records each recursive parameter on the raw
16.16 grid. Check parent/child split arithmetic with:

```sh
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_splits.py /tmp/m11-calctrace/trace.log
```

This verifies the source q-path subdivision for each target lane:

```sh
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_splits.py /tmp/m11-tube-outline-trace/trace.log \
  --call 4 --lane 2
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_splits.py /tmp/m11-tube-outline-trace/trace.log \
  --call 4 --lane 6
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_splits.py /tmp/m11-tube-outline-trace/trace.log \
  --call 5 --lane 2
```

The checked tree contains respectively 19, 9 and 14 left/right child pairs;
all controls match fixed-point de Casteljau with nearest-unit rounding. This
confirms the split operation across all three divergent lanes. The branch
mismatch therefore remains in how Typst selects and parameterizes a cut or
evaluates its width threshold, rather than in q-control subdivision itself.

Typst now has `_mp-cubic-split` and `_mp-cubic-path-split` using the same
dimensional and scalar 16.16 quantizers. Generate the paired controls and
compare the Typst result:

```sh
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_splits.py /tmp/m11-calctrace/trace.log \
  --typst-output build/m11-q-split-cases.typ
nix develop path:./nix --command typst eval \
  'query(<m11-q-split-replay>).first().value' \
  --in diagnostics/m11_q_split_replay.typ --root .
```

The Typst replay matches all 19, 9 and 14 left/right child control arrays for
the three divergent lanes after 16.16 quantization. `_ink-loops` does not yet
carry these q curves between recursive nodes, so production output is
unchanged.

Future knot-insertion candidates should rebuild the source
`offsetPathTemplate` width knots at integer post-cut times, including the
repeated endpoint callback values, before evaluating brush recursion.

The expanded trace also records the outer `brushGenerate` q controls as
`M11BQPT` and its `cutPathTime` result as `M11BRCUT` for call 4/lane 2. Its
40-segment root q path cuts at time `22.33324`; the left `subpath` is then
reparameterized to 23 unit-time segments, and the next source cut is at
`22.9997`. This establishes that a partial final cubic becomes a full local
path-time interval after `subpath`.

A diagnostic candidate carried fixed-point q controls through the recursive
subpaths and tracked each subpath's remapped source-time knots. It did not
improve the tree: call 4/lane 2 stayed at 18 Typst calls versus 16 source;
the candidate had 56 thin nodes and paired 30/40 source node endpoints,
compared with 34 thin nodes and 32/40 endpoint pairs for the baseline. The
production change was removed. The next attempt needs to pair the remapped
q-time knots with the source centerline's subpath parameterization before
changing cut selection.

`extract_m11_shadow_brush_inputs.py` exports the traced post-shadow cubic
paths, their integer callback widths and source-order RNG offsets as a Typst
module. `m11_shadow_brush_replay.typ` feeds these inputs directly to the
production `_ink-loops` recursion with source rounding and path-time width
interpolation. This removes lane reconstruction and callback evaluation from
the comparison, so remaining call-count differences are in brush recursion
or its low-level arithmetic. Reproduce the four-sample-per-cubic replay with:

```sh
nix develop path:./nix --command python \
  diagnostics/extract_m11_shadow_brush_inputs.py \
  /tmp/m11-center-all/trace.log build/m11-shadow-brush-inputs.typ \
  --samples-per-cubic 4
nix develop path:./nix --command typst eval \
  'query(<m11-shadow-brush-replay>).first().value' \
  --in diagnostics/m11_shadow_brush_replay.typ --root . \
  > build/m11-shadow-brush-replay.json
```

On the current pinned trace, 15 of 18 lane call totals match exactly. The
remaining differences are call 4 lane 2 (`18` vs source `16`), call 4 lane 6
(`8` vs `6`), and call 5 lane 2 (`12` vs `14`). Calls 1–3 and 6 match on all
three traced lanes; the other call-4–6 lanes also match. Increasing path
sampling from one, two, four, eight, sixteen, or thirty-two points per source
cubic leaves these call totals unchanged. This narrows the three mismatches
beyond path density,
but does not yet identify a production-safe recursive change. No renderer
change is implied by this diagnostic.

A newer source-q replay narrows the remaining work. The generated input now
includes the traced 16.16 q cubic controls as an oracle, and the recursion
carries those controls with the exact source-time map. Replaying against
`/tmp/m11-q-full/trace.log` gives all 18/18 source lane call totals;
`compare_m11_thin_trees.py` confirms exact node decisions and q controls on
the formerly divergent lanes: call 4/lane 2 has 40 nodes, call 4/lane 6 has
20, and call 5/lane 2 has 30. Reproduce with:

```sh
nix develop path:./nix --command python \
  diagnostics/extract_m11_shadow_brush_inputs.py \
  /tmp/m11-q-full/trace.log build/m11-shadow-brush-inputs.typ \
  --samples-per-cubic 4
nix develop path:./nix --command typst eval \
  'query(<m11-shadow-brush-replay>).first().value' \
  --in diagnostics/m11_shadow_brush_replay.typ --root . \
  > build/m11-shadow-brush-replay.json
nix develop path:./nix --command python \
  diagnostics/compare_m11_thin_trees.py \
  /tmp/m11-q-full/trace.log build/m11-shadow-brush-replay.json
```

This is an exact-state recursion oracle, not a general renderer fix: q cubics
come from source trace records and are injected into the replay. The remaining
implementation gap is constructing those q controls from the post-shadow
callback/template knots and using that generated state in production. The
earlier 15/18 result above records replays without this complete injected q
state and is superseded for the exact-state diagnostic only.

The exact-state replay does not need the source q controls if it receives the
source arc knots. `M11POSTFIX` records each post-shadow centerline cubic in
16.16 bp coordinates, and `M11POSTARC` records MetaPost's cumulative
`arclength(subpath(0, i) of currentPath)` at each integer path-time knot.
`audit_m11_q_arclength.py` checks these records against the root q template:
all traced q x endpoints equal the source arc values, and every q control is
the exact 16.16 one-third/two-third linear control between adjacent arc and
callback-width endpoints. With only source arc knots and widths injected,
`m11_shadow_arc_replay.typ` builds the q controls in Typst and matches the
same exact 40/40, 20/20, and 30/30 source trees. Reproduce with:

```sh
nix develop path:./nix --command python \
  diagnostics/audit_m11_q_arclength.py /tmp/m11-q-audit/trace.log
nix develop path:./nix --command python \
  diagnostics/extract_m11_shadow_brush_inputs.py \
  /tmp/m11-q-audit/trace.log build/m11-shadow-brush-inputs.typ \
  --samples-per-cubic 4
nix develop path:./nix --command typst eval \
  'query(<m11-shadow-arc-replay>).first().value' \
  --in diagnostics/m11_shadow_arc_replay.typ --root . \
  > build/m11-shadow-arc-replay.json
nix develop path:./nix --command python \
  diagnostics/compare_m11_thin_trees.py \
  /tmp/m11-q-audit/trace.log build/m11-shadow-arc-replay.json
```

The cubic integral computed from the exact fixed-point center controls differs
from MetaPost's arc values by at most 21.337 fixed units (mean 9.371). A
16-sample-per-cubic polyline is closer than 32 samples on this trace (maximum
9.140 versus 16.023 units), but neither sampling choice reconstructs all three
trees. Fixed-point implementations of MetaPost's recursive `arc_test` and
`pyth_add` in both the audit script and `fiziko.typ` reproduce all 121 traced
M11 segment arc lengths exactly (maximum and mean error 0 in 16.16 units).
The Typst diagnostic now reconstructs cubic controls directly from quarter
and three-quarter sample points, computes the arc, and feeds an isolated q
replay. Reconstructing center cubics from their quarter and three-quarter
samples produces source arc lengths within 2 fixed units (maximum; mean
0.587). Using these reconstructed cubics, Typst-computed arc knots, and the
source callback widths still matches all 40, 20, and 30 recursion nodes and
their q controls exactly. The diagnostic samples come from traced source
curves; other 15 lane inputs still use source arc knots, so production q
template generation from its own sampled paths remains to be integrated.
Re-run the paired check with:

```sh
nix develop path:./nix --command python \
  diagnostics/audit_m11_q_arclength.py /tmp/m11-q-audit/trace.log \
  --typst-fixture build/m11-fixed-arc-fixture.typ
nix develop path:./nix --command typst eval \
  'query(<m11-fixed-arc-check>).first().value' \
  --in diagnostics/m11_fixed_arc_check.typ --root . \
  > build/m11-fixed-arc-results.json
nix develop path:./nix --command python \
  diagnostics/extract_m11_shadow_brush_inputs.py \
  /tmp/m11-q-audit/trace.log build/m11-shadow-brush-inputs.typ \
  --samples-per-cubic 4 --arc-json build/m11-fixed-arc-results.json \
  --arc-json-field reconstructed-arcs
nix develop path:./nix --command typst eval \
  'query(<m11-shadow-arc-replay>).first().value' \
  --in diagnostics/m11_shadow_arc_replay.typ --root . \
  > build/m11-shadow-arc-replay.json
nix develop path:./nix --command python \
  diagnostics/compare_m11_thin_trees.py \
  /tmp/m11-q-audit/trace.log build/m11-shadow-arc-replay.json
```

MetaPost's documented `arclength` uses recursive bisection and an adaptive
Simpson estimate ([source manual, sections 399–414](https://tug.ctan.org/info/knuth-pdf/mp/mp.pdf)); the verified fixed-point implementation now supplies the arc-length primitive needed for the remaining q-template integration.

### M11 q replay from production lane samples

The q replay can now use the actual sampled inner lanes emitted by
`m11_knot_tube_trace.typ`, rather than center cubics sampled from the source
trace. A geometry comparison pairs source call/lane records to the Typst
segments: source call 4/lane 2 and 4/lane 6 pair to strand 1/segment 0/lanes 5
and 1; call 5/lane 2 pairs to strand 1/segment 2/lane 5. The exporter then
maps those samples through the traced `shadowCut` time splices and supplies the
source callback widths. Its source-arc mode matches all three complete trees,
confirming the geometry pairing and splice map. With arcs calculated from the
Typst samples, call 4/lane 6 still matches its 20-node tree; calls 4/lane 2
and 5/lane 2 each stop two nodes early (38/40 and 28/30). Their segment arc
errors peak at 24–26 fixed units, with about 9.2 units mean absolute error.
Mapped post-shadow lane points differ from traced source cubics by at most
0.00147 mm (mean 0.00028 mm); largest residuals cluster around segments
18–31 depending on lane, rather than only at inserted connectors.
A fifth-sample least-squares cubic fit shifts the error but is not a universal
fix: it recovers call 5/lane 2 while changing call 4/lane 6 to 22 nodes. Keep
the quarter-sample implementation as the measured baseline; no production
renderer change is claimed.

The q-replay's recursive arc-offset result must not be mistaken for a current
production q tree. `m11_knot_tube_trace.typ` calls `_ink-loops` without
`source-width-fixed` or `source-q-curves-fixed`; its baseline trace therefore
has no q curves. A temporary diagnostic passed its sampled lane widths back as
16.16 `source-width-fixed`, causing `_ink-loops` to build q curves from the
sampled-frame chord arcs. That candidate changed aggregate M11 knot-lane and
edge calls from 212 to 208, farther from the source total of 224; its
source-ordered vector changed from `38/56/14/10/40/54` to
`38/54/14/10/40/52`, while its L1 error against source
`14/58/54/42/38/18` remained 136. It was removed without a raster trial. The
next production task is to carry the source callback q
template into the real lane renderer, not to promote the replay's local x
offset as though the renderer already used that q state.

Rebuild the actual Typst lane trace and compare generated, fifth-fit, and
source-arc q trees with:

```sh
nix develop path:./nix --command typst eval \
  'query(<m11-knot-tube-trace>).first().value' \
  --in diagnostics/m11_knot_tube_trace.typ --root . \
  > build/m11-knot-tube-trace.json
nix develop path:./nix --command python \
  diagnostics/extract_m11_typst_q_inputs.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace.json \
  build/m11-production-q-inputs.typ
nix develop path:./nix --command typst eval \
  'query(<m11-production-q-replay>).first().value' \
  --in diagnostics/m11_production_q_replay.typ --root . \
  > build/m11-production-q-replay.json
nix develop path:./nix --command python \
  diagnostics/compare_m11_thin_trees.py \
  /tmp/m11-q-audit/trace.log build/m11-production-q-replay.json
nix develop path:./nix --command python \
  diagnostics/compare_m11_thin_trees.py \
  /tmp/m11-q-audit/trace.log build/m11-production-q-replay.json \
  --nodes-field source-arc-q-nodes
```

Removing the injected q controls and increasing only the sampled center-curve
density does not recover all three trees. At 8 samples per cubic, calls 4/lanes
2 and 6 match their 40- and 20-node trees, but call 5/lane 2 grows to 36 nodes
against 30 source nodes. At 1, 16, and 32 samples per cubic, both call 4/lane 2
and call 5/lane 2 also differ from source. Since denser sampling changes
estimated centerline arc positions and the branch results are non-monotonic,
do not treat sampling density as the q-template fix. The next probe should
compare source q knot abscissae to source `arclength(subpath(...))` values
before implementing the generic template builder.

The replay now samples callback widths linearly in source path time. This
matches `offsetPathTemplate`, which joins its integer-time callback points with
MetaPost `--` segments. The previous diagnostic interpolated widths by
centerline arc length and therefore changed the input curve. With source
path-time interpolation, the replay still matches 15/18 lane totals and leaves
the same three differences. This rules out arc-length resampling as their
cause; production rendering is unchanged.

A fresh replay from the same source trace and Typst lane trace confirms the
boundary of the remaining error. Injecting the traced source arc knots yields
exact q controls and exact trees on all three paired lanes: 40/20/30 nodes.
Reconstructing arcs from the actual Typst lane samples yields 38/20/28 nodes.
The cumulative q-abscissa offsets peak at 58, 49, and 62 16.16 units for
call/lane 4/2, 4/6, and 5/2, at knots 33, 32, and 21 respectively. Source and
Typst post-shadow curve samples still differ by at most 0.00147 mm, so small
per-segment geometry errors accumulate into the later q knots. Quarter-sample,
fifth-sample, and blended cubic fits move the divergent lane but do not
recover all three trees together. The next probe should target cumulative knot
alignment across post-shadow segments, while retaining source time splices and
callback widths; no production change is justified until all three trees and
the M11/M4/M6 image gates improve together.

As a bounded diagnostic, linearly distributing each lane's final cumulative
arc error over its interior knots was also tried, using the traced source end
arc as an oracle. This endpoint-only correction made the trees `38/22/28`,
with first differences at nodes `18/11/6`; it did not recover the source
`40/20/30` trees. A total-length scale therefore does not explain the interior
drift. The temporary replay branch was removed. Further work must locate local
arc offsets around the divergence knots rather than tune only the final length.

A 1%-step sweep of the quarter/fifth arc blend also found no coefficient that
recovers all three trees at once. Exact-tree blend intervals were 10–12% and
30–37% for call 4/lane 2, 0–50% for call 4/lane 6, and 17–25%, 51–75%, and
84–100% for call 5/lane 2. Their intersection is empty. This rules out a
single global blend as the correction; the best intervals vary by lane and
the sweep branch was removed after measurement.

The lane trace also emits a diagnostic-only `dense-points` path, evaluating
`center-at + normal-at * u * rfun` at four intermediate positions between
every existing lane knot. Exporting these 16 points per path-time unit reduces
source-cubic point residuals on calls/lanes 4/2, 4/6, and 5/2 from max/mean
`0.001235/0.000262`, `0.001474/0.000284`, and `0.001262/0.000291` mm to
`0.000529/0.000182`, `0.000572/0.000186`, and `0.000548/0.000215` mm.
Cumulative arc-knot errors fall from 58/49/62 to 23/24/17 fixed units. Yet
quarter-fit q trees remain 38/20/28 versus source 40/20/30; a residual-weighted
per-segment fit recovers the latter two lanes but not call 4/lane 2. Doubling
the dense subdivisions again did not further reduce point residuals and
changed the third tree to 34 nodes. This is a geometry improvement in the
diagnostic, not by itself a production result. A temporary production trial
and its image gate follow.

A temporary `lane-subdivisions: 4` production option sampled each M11 inner
offset directly at the same four intermediate positions and rendered at 600
ppi. Against the paired baseline, whole-plate RMSE changed from
`0.11291172` to `0.11290663`, globe crop from `0.18994728` to `0.18989648`,
but knot crop regressed from `0.05823034` to `0.05831953`. The small full-page
gain does not compensate for the knot crop regression; the production option
and M11 setting were removed. Keep only the diagnostic dense path. Any future
production geometry change must pass the knot and globe crop gates, not only
whole-page RMSE.

Generate and replay the diagnostic dense lane samples with:

```sh
nix develop path:./nix --command typst eval \
  'query(<m11-knot-tube-trace>).first().value' \
  --in diagnostics/m11_knot_tube_trace.typ --root . \
  > build/m11-knot-tube-trace-dense.json
nix develop path:./nix --command python \
  diagnostics/extract_m11_typst_q_inputs.py /tmp/m11-q-audit/trace.log \
  build/m11-knot-tube-trace-dense.json build/m11-production-q-inputs.typ \
  --dense
nix develop path:./nix --command typst eval \
  'query(<m11-production-q-replay>).first().value' \
  --in diagnostics/m11_production_q_replay.typ --root . \
  > build/m11-production-q-replay-dense.json
```

The production-lane arc audit compares straight accumulation over the four
Typst samples per segment with a MetaPost-fixed cubic fitted from the quarter
samples. The cubic fit reduces mean absolute 16.16 arc error from
`14.175/12.805/14.075` to `9.350/8.902/9.325` units for source call/lane
`4/2`, `4/6`, and `5/2`; maximum errors fall from `52/61/52` to `24/26/24`.
That is a better arc estimate, but it is not a universal tree correction:
the generated q replay has `38/20/28` nodes against source `40/20/30`.
Fitting with the fifth sample restores call `5/2` to 30 nodes but changes
call `4/6` to 22. Keep the quarter-fit as the measured geometric estimate,
not a renderer change. Reproduce the audit with:

```sh
nix develop path:./nix --command python \
  diagnostics/make_m11_production_arc_fixture.py \
  /tmp/m11-q-audit/trace.log build/m11-knot-tube-trace.json \
  build/m11-production-arc-fixture.typ
nix develop path:./nix --command typst eval \
  'query(<m11-production-arc-check>).first().value' \
  --in diagnostics/m11_production_arc_check.typ --root . \
  > build/m11-production-arc-check.json
```

The source q abscissae themselves agree exactly with the pinned 16.16
MetaPost arc-length port on all three lanes (zero fixed-unit mismatch). The
remaining source-versus-production arc deltas therefore come from the
reconstructed production cubics: segment errors change sign, ranging from
`-22` to `+24` units on call `4/2`, `-26` to `+18` on `4/6`, and `-22` to
`+24` on `5/2`. Their cumulative endpoint deltas are `-42`, `-35`, and `-43`
units, with intermediate absolute maxima of 58, 49, and 62. This rules out a
constant whole-path scale correction. On calls `4/2` and `5/2`, the tree
diverges at the final thin decision, where a compared width endpoint is within
`0.00001 mm` of the recursion threshold. A useful next probe must
localize post-shadow arc errors around those leaves; source q-knot injection
is not a production fix because its prior full-plate comparison regressed.

The thin-node trace now retains the reason a source-q split was rejected.
At the first differing leaf on call `4/2` (node 33) and `5/2` (node 20),
the production arc estimate finds only the right-ray hit at q time `4.0`, the
end of its four-piece q path; the left ray has no hit. The endpoint maps to
the end of the lane, so the source path-time guard rejects it. Replaying the
same node with source arc knots finds an interior right-ray hit at `3.93918`
and `3.93916`, respectively, and recurses. This isolates the branch mismatch
to which q-curve intersection survives the midpoint ray selection. The trace
field is diagnostic-only; no production shading or geometry changed. Keep the
local q x-knots and ray bounds under investigation before attempting a global
arc correction.

The source instrumenter also emits `M11TCUTQ` at the chosen thin-brush cut:
the evaluated q point, target width, and q bounding-box x limits. On source
calls 4/lane 2 and 5/lane 2, the decisive cut lies about `0.00006 mm` above
the target width and about `0.0059 mm` before the q curve's right x bound.
At those same recursive nodes, source and generated q controls have identical
y coordinates, while the generated x coordinates differ by 41–58 and 45–62
16.16 units. Increasing packet-search tolerance steps through 6, 12, 24, and
48 did not change the generated trees (38/20/28 nodes, versus source 40/20/30)
or call counts (16/6/14). This rejects a tolerance-only correction. The next
probe should compare the source and generated q x parameterization at the
interior cut, including its local derivative, before changing production
geometry; the source cut point is near the width threshold, not the curve
endpoint.

Evaluating the final q cubic at the source cut parameter refines that result.
For call 4/lane 2 (`u=0.93918`) and call 5/lane 2 (`u=0.93916`), generated
q x is behind the source by 43.18 and 47.18 fixed units, respectively
(`0.000232` and `0.000254 mm`). Their local x derivatives differ by only 3
fixed units per segment, about `0.017%`; y controls and derivatives are
identical. The mismatch is therefore almost a constant x translation across
the final cubic, consistent with a cumulative arc-origin offset inherited
from earlier knots. A useful correction must carry that offset through
recursive child paths from their parent arc mapping; changing local cubic
shape or packet tolerance does not address this evidence.

The paired derivative report is reproducible with:

```sh
nix develop path:./nix --command python \
  diagnostics/analyze_m11_q_parameter_offset.py \
  /tmp/m11-q-audit/trace.log build/m11-production-q-replay-debug-default.json
```

It pairs source and generated recursive nodes by call/lane and center-path
endpoints. On the current trace it reports eight near-endpoint cuts; the two
branch-divergent cuts are the `4/2` and `5/2` rows at `t=3.93918` and
`t=3.93916`, respectively. Both have zero q-y value and derivative error at
the paired local parameter, while their q-x offsets are almost constant.

Rounding `param-at` results onto the source 16.16 path-time grid also left the
same 15/18 lane call totals. On a 600 ppi M11 render it slightly regressed
whole RMSE `0.1128986841 → 0.1128987766` and knot-crop RMSE
`0.0582292769 → 0.0582303411`; the candidate was reverted.

A production trial inserted lane knots at shifted-outline intersections and
resampled widths on the resulting time grid. It produced per-segment calls
`14/54/54/34/34/16` (206 total) versus source `14/58/54/42/38/18`; the
pre-trial baseline was `14/56/54/38/40/10` (212 total). Absolute segment
error increased from 16 to 18. At 600 ppi whole M11 RMSE regressed
`0.11295018 → 0.11301771` and the knot crop `0.05881920 → 0.05958444`; the
production edit was reverted. Any next candidate must preserve the source
width-template interpolation and reproduce exact intersection timing as well
as its inserted cubic knots.

The projection orientation is independently checked on source call 4, lane
k=2. Its pre-cut lane and the shifted high-layer outline at `(rank=1,
segment=4)` intersect first at source path time `21.78946`; intersecting the
recorded cubic/polyline geometry predicts `21.7896`. The next geometric hit is
at pre-cut time `26.0622`. After the first `shadowCut` splice, the source
reports it at `28.06259`, matching the splice's two-unit path-time advance.
The connector at the first hit matches the original cubic subcurve over
`[21.73946, 21.83946]`; the second connector similarly matches its original
subcurve within `1.7e-5` mm. This pins the projection direction and confirms
that the operation inserts knots without materially changing this lane's
geometry.

The same instrumenter emits source lane widths (`M11BW`) and random-call
counts (`M11LANE`). The paired Typst trace in
`m11_knot_tube_trace.typ` records each inner and boundary lane's sampled
points, widths, and call count. Edge recursion now uses the same 16.16 source
rounding as production `stroke-ink`; older 202-call totals omitted that edge
rounding and are superseded. All six source tube intervals pair to Typst paths
with exact endpoints. With the retained source-cubic centerline, aggregating
each Typst path's inner and two boundary lanes gives 212 calls in source draw
order (`38/56/14/10/40/54`); the source uses
`14/58/54/42/38/18` (224 total). For source tube call 2, lane k=6 pairs
geometrically with Typst inner lane 1 (mean point distance 0.000038 mm). Its
source effective width peaks at 0.04525 mm, while the paired Typst profile
peaks at 0.05496 mm; the brush consumes 38 source calls and 10 Typst calls on
this lane. The older 0.03634 mm figure came from comparing against Typst lane
5 and is not a valid pairing. The radial-y shade formula trial moves this lane
to 34 calls, but its full M11/M4/M6 renders regress, so it remains discarded.
A rerun of that source-lighting width model with rounded boundary recursion
gives 212 calls in source call order (`14/56/54/38/40/10`); source is
`14/58/54/42/38/18`. Calls 1–3 are within two calls each, while calls 4–6
account for the remaining 12-call deficit. The source-lighting render still
regresses M11, so this remains a diagnostic lead rather than a retained
render change.
The refreshed JSON retains complete baseline and candidate recursion trees for
inner lanes k=2 and k=6 plus both boundary sides, across all six intervals.
On calls 4–6, source/Typst sample positions differ by up to 0.010–0.024 mm and
candidate surface-normal L2 error remains 0.07–0.15; these intervals account
for a net 10-call shortfall (call 5 has a 2-call surplus); call 2 contributes
the remaining 2-call deficit. The earlier call-count probes in this
section used unrounded boundary recursion and should be read as historical
only.
A separate trial that reduced the dense Typst width profile to quarter-path-
time knots and interpolated by lane arc also regressed the six-segment
call-count agreement and was reverted.

- `figure12_*`, `instrument_metapost.py`, `instrument_recursion.py`, and
  `compare_latitudes.py`: latitude geometry and recursion traces.
- `m4_*`, `m6_*`, `tube_longitudinal_nodes.typ`, and
  `instrument_tube_lanes.py`: longitudinal tube comparisons and lane traces.
- `s101_*`, `brush_scale_probe.*`, `instrument_brush.py`,
  `compare_brush_trace.py`, and `summarize_stipple_trace.py`: stipple and
  brush comparisons, including scale probes.
- `stipple_density_scan.py`, `stipple_surface_scan.py`, and
  `transverse_dash_scan.py`: the 600 ppi multi-scale/seed audit for stage 4.

For routine source/Typst comparisons, use the
[reproducible comparison workflow](../comparisons/README.md). The commands
below are historical low-level trace investigations, run inside
`nix develop path:./nix`; the upstream source is available at
`$FIZIKO_UPSTREAM_PATH/fiziko.mp`. MetaPost trace drivers depend on
instrumented copies generated by those commands. Typst files import the
library from the parent directory; invoke them from the repository root with
`--root .`. The isolated `s101_tube_stipple_compare.typ` additionally needs
`--input density=0.56` (or the density being investigated).

## Figure 12 latitude comparison

This trace records a source-alignment investigation. Its MetaPost leaf and
dash-call counts explain visual differences; matching them exactly is not a
project requirement when a simpler, faster Typst rendering is preferable.
The checked-in CSV files were generated with the former 360-sample default
and MetaPost RNG replay. `figure12_trace.typ` requests 360 samples explicitly
for that geometry study; the visible default now uses 180 samples and local
deterministic randomness, so those counts are historical diagnostics.

`figure12-before.csv` and `figure12-after.csv` contain one row per parallel in
the two balls from the upstream Figure 12 example. Each row compares path
length, width range, outer brush leaves, drawable thin leaves, dash pattern
calls, knot counts, and maximum knot errors. All lengths and widths in the CSV
are millimetres. The source values
come from MetaPost's own path and width template; the Typst values come from
`sphere-latitude(..., with-trace: true)`.

| Ball | Source dash calls | Before | After | Source outer leaves | After |
| --- | ---: | ---: | ---: | ---: | ---: |
| 20 mm, latitude −60° | 518 | 474 | 486 | 273 | 112 |
| 30 mm, latitude 45° | 746 | 661 | 653 | 309 | 156 |

The remaining dash-call deficit is spread across many parallels. In the 20 mm
ball the largest gaps are parallel 54 (5 calls) and 76 (4 calls); in the 30 mm
ball parallel 38 is short by 5 calls, while 34, 40, 42, 50, 56, 60, 62, 94,
and 98 are each short by 4. The large outer-leaf gap at parallel 68 of the
20 mm ball (28 versus 5) contributes only one missing dash call: most of its
extra MetaPost leaves are tiny solid pieces.

The second change keeps the original `offsetPathTemplate` knots in the Typst
brush path and reproduces MetaPost's 16.16 fixed-point angle step. Before this,
one parallel had a different knot count; now all 177 parallels match MetaPost,
with 4,561 knots in total. The largest observed knot-width difference fell from
0.000392 to 0.000104 mm, and the largest knot arc-position difference fell from
0.0599 to 0.00176 mm. A major remaining leaf-count difference
comes from repeated near-endpoint cuts in MetaPost's `cutPathTime` recursion;
the next comparison should focus on that behavior.

The recursion now also accepts the original width-template segment parameter
for endpoint checks instead of treating `0.01` as a physical `0.01 mm` arc
length. `sphere-latitude` supplies this parameter from its retained template
knots. Re-running the same 177-parallel Figure 12 trace leaves the totals
unchanged: source/Typst outer leaves are 582/268, thin leaves 1,750/1,312,
and dash calls 1,264/1,139. The largest per-line thin-leaf deficits are also
unchanged (latitude 62: 45/18; latitude 94: 29/9; latitude 53: 27/9 on the
30 mm ball). The inner endpoint guard was not the cause of that mismatch. The
outer source macro uses a distinct condition (`t > 0`, with no 0.01 margin), so
the Typst outer recursion now uses zero margin while the inner thin recursion
retains 0.01 in template-segment units. On the same trace, outer leaves rise
from 268 to 278, thin leaves stay at 1,312, and dash calls move from 1,139 to
1,134; source totals are 582, 1,750, and 1,264. This narrows the outer-leaf
gap slightly but moves the dash count farther away.

The fixed M3 sphere crops also score slightly worse with the source's zero
outer margin: the 20 mm crop changes from RMSE 0.16335 / 7.170% coverage to
0.16693 / 7.155% (source 7.183%); the 30 mm crop changes from 0.18360 /
7.427% to 0.18489 / 7.427% (source 7.444%). Keep the distinct outer and inner
conditions because they match their separate source branches, while treating
the phase-sensitive raster regression as unresolved.

The node-level trace for the worst 30 mm sphere parallel (latitude 62) shows
that the main split geometry already agrees closely. At the root, MetaPost's
cut parameter is 9.2096 and Typst's retained source parameter is 9.20997; the
root path lengths differ by 0.000012 mm, and the left-child lengths differ by
0.0101 mm. On the first thin-brush node, target widths differ by 0.0000042 mm
and left-child lengths by 0.0000085 mm. The native MetaPost path parameter can
differ from Typst's sampled parameter even when the split arc lengths agree.

The large recursion-count difference has a more specific cause at the root's
right endpoint: MetaPost evaluates its maximum width as 0.19926 bp against a
0.19925 bp threshold. That roughly 0.0000035 mm overshoot triggers a chain of
near-zero-length outer splits to the depth limit. Typst sees the endpoint at
the threshold and stops splitting. For this parallel, MetaPost records 23
outer nodes (11 recursive decisions) and 92 thin nodes (45 recursive
decisions); Typst records 5 outer nodes (2 recursive decisions) and 38 thin
nodes (18 recursive decisions). The extra source nodes are concentrated in
the threshold-sized sliver, rather than indicating a broad mismatch in the
latitude geometry. Keep the current Typst boundary behavior for now: the
earlier zero-margin experiment slightly reduced the outer-leaf count gap but
worsened both fixed M3 crop scores. There is no image-level evidence that
reproducing the threshold residue would improve the plate.

To regenerate this node trace from the unmodified upstream source:

```sh
python3 diagnostics/instrument_recursion.py "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/fiziko-recursion-source.mp
cat > /tmp/figure12-recursion.mp <<'EOF'
input "/tmp/fiziko-recursion-source.mp";
randomseed := 1;
beginfig(12);
draw sphereLat(3cm,45);
endfig;
end
EOF
cd /tmp
mpost -interaction=nonstopmode -halt-on-error -jobname=figure12-recursion /tmp/figure12-recursion.mp
cd -
typst eval 'query(<figure12-recursion-nodes>).first().value' --in diagnostics/figure12_nodes.typ --root . > /tmp/figure12-nodes-typst.json
```

The source transcript is `/tmp/figure12-recursion.log`. Its arc lengths and
widths are MetaPost bp; convert them to millimetres with `25.4 / 72` before
comparing against the Typst JSON.

## M4 longitudinal tube lane order

A lane-by-lane trace of the constant-radius M4 tube found that Typst's lane
positions were mirrored across the tube section. The source interpolates its
lanes from `+radius` to `-radius`; the previous Typst formula ran from
`-radius` to `+radius`. Reversing the Typst lane coordinate while leaving its
lightness formula unchanged makes source and Typst width ranges line up by
lane index. Across 63 interior lanes, the mean sum of the min/max width errors
is 0.00093 mm (the largest is 0.00596 mm near the brightest lanes).

At 600 ppi, the corrected M4 plate improves whole-frame RMSE from 0.069273 to
0.068799. Dark coverage is 1.508% versus 1.506% in the source. The same lane
order correction also improves the variable-radius M6 plate from RMSE 0.08743
to 0.08584; coverage is 1.964% versus 1.958% in the source. The per-lane
recursion counts still differ, so short dash placement and phase remain open.

### M4 source centerline

The M4 comparison used 40 exact-circle samples in Typst, while its pinned
MetaPost driver connects the same 41 anchors with MetaPost's cubic path solver.
`instrument_m4_tube_path.py` and `extract_m4_tube_path.py` now export that path
at 1/16 path-time intervals (641 points) into `comparisons/m4-tube-path.typ`.
Using the source-derived centerline lowers nominal 600 ppi RMSE from 0.07025
(the 1/8 result was 0.06050) to 0.06019; Typst ink coverage is 1.756% versus
1.789% in the source. The 1/16 comparison takes 125.7 s and retains the
existing lane model and dash stream; remaining width and dash differences are
independent. A 1/32 candidate (1281 points) did not complete: Typst exited
with status -9 during the comparison after several minutes, before producing
metrics. Keep 1/16 as the best completed source-path sample.

A `per: 0` pilot that connected the 641 source samples directly (without the
additional Hobby resampling used by the fixture's `per: 4`) scored 0.06055,
with ink coverage 1.756% versus 1.789% source. It was reverted; the smoother
Hobby reconstruction currently gives better tangents and brush placement.
The S104 16.16 recursive-cut change leaves the M4 600 ppi RMSE and ink hash
unchanged at 0.060190/1.756%, so the shared cut-time fix does not regress this
constant-radius tube. Variable-radius lane geometry and source-exact tangent
lightness remain open.

Regenerate the M4 path from the pinned comparison driver inside the Nix shell:

```sh
mkdir -p /tmp/m4-tube-source
python3 diagnostics/instrument_m4_tube_path.py \
  comparisons/reference/main.mp /tmp/m4-tube-source/main.mp 16
cp "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m4-tube-source/fiziko.mp
printf 'selected := 4; input main.mp;\n' > /tmp/m4-tube-source/trace.mp
(cd /tmp/m4-tube-source && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
python3 diagnostics/extract_m4_tube_path.py \
  /tmp/m4-tube-source/trace.log comparisons/m4-tube-path.typ
```

A matching M7 source-spline trace is kept as `diagnostics/m7-tube-path.typ`.
At 1/8 path-time intervals (25 points), substituting that centerline into the
transverse-tube comparison changed nominal 600 ppi RMSE from 0.12453 to
0.12542, with near-identical ink coverage (3.934% vs 3.936%). The sampled
centerline follows the source cubic geometry, but the complete transverse
render did not improve, so the comparison still uses its original anchor
polyline until the transverse spacing and random phase are better aligned.

Regenerate the M7 candidate geometry from the pinned driver:

```sh
mkdir -p /tmp/m7-tube-source
python3 diagnostics/instrument_m7_tube_path.py \
  comparisons/reference/main.mp /tmp/m7-tube-source/main.mp 8
cp "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/m7-tube-source/fiziko.mp
printf 'selected := 7; input main.mp;\n' > /tmp/m7-tube-source/trace.mp
(cd /tmp/m7-tube-source && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
python3 diagnostics/extract_m7_tube_path.py \
  /tmp/m7-tube-source/trace.log diagnostics/m7-tube-path.typ
```

The source lane trace uses the same 110 × 56 mm path as M4. The two Typst
comparison documents render the calibrated M4 and variable-radius M6 samples:

```sh
python3 diagnostics/instrument_recursion.py "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/fiziko-m4-recursion.mp
python3 diagnostics/instrument_tube_lanes.py /tmp/fiziko-m4-recursion.mp /tmp/fiziko-m4-lanes.mp
project=$PWD
cd /tmp
mpost -interaction=nonstopmode -halt-on-error -jobname=m4-lanes "$project/diagnostics/m4_longitudinal_lanes.mp" > /tmp/m4-lanes.stdout
cd "$project"
typst eval 'query(<m4-longitudinal-lane-traces>).first().value' --in diagnostics/tube_longitudinal_nodes.typ --root . > /tmp/m4-lanes-typst.json
typst compile --root . diagnostics/m4_longitudinal_compare.typ /tmp/m4-longitudinal.pdf
typst compile --root . diagnostics/m6_variable_tube_compare.typ /tmp/m6-variable-tube.pdf
```

An analogous source-sampled M6 `fullcircle` path at 1/8 path-time produced
RMSE 0.09006 versus 0.08919 for the current ideal-circle path when the radius
sine followed the source traversal. Reversing the sine to keep the old phase
raised RMSE to 0.16438. Both candidates were removed; M6's closed-path radius
parameterization needs a separate trace before another geometry change.

To regenerate the comparison from an upstream `fiziko.mp`, make a diagnostic
copy and run the included MetaPost and Typst drivers:

```sh
python3 diagnostics/instrument_metapost.py "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/fiziko-diagnostic-source.mp
mpost -interaction=nonstopmode diagnostics/figure12_diagnostic.mp > /tmp/figure12-mp.log
typst eval 'query(<traces>).first().value' --in diagnostics/figure12_trace.typ --root . > /tmp/figure12-typst.json
python3 diagnostics/compare_latitudes.py /tmp/figure12-mp.log /tmp/figure12-typst.json /tmp/figure12.csv
```

The two checked-in CSV files record the state before and after keeping the
original knots. The source run used jemmybutton/fiziko's `fiziko.mp` with
MetaPost 2.11 and random seed 1.

## S101 stippled-brush recursion trace

The instrumenter now also records every recursive node's endpoint widths,
arc length, cut parameter and child lengths, plus whether MetaPost recurses.
On the pinned S101 brush it records 139 nodes, 69 recursive splits, a maximum
depth of 14 and 70 terminal nodes; 60 terminal nodes pass the stipple draw
gate. Each drawable leaf contributes three local patterns (180 calls). The
trace reconstructs 217 source dots. Their diameters are independently drawn
per pattern call (0.26984–0.35800 MetaPost bp, mean 0.31245 bp).

Open `stroke-stipple-brush` paths now approximate that recursive structure:
quantized target widths, width-driven cuts, minimum child lengths, a depth
limit, local pattern restarts, paired phase offsets and per-leaf seeded dot
sizes. A scalar-width simulation gives 137 nodes and 68 splits, with the same
maximum depth of 14 as the source. It approximates MetaPost's cut geometry;
the keyed Typst RNG does not replay MetaPost's global stream. Closed paths
retain the previous continuous ring distribution.

At the S101 settings (`per: 48`, `seed: 1`), a three-scale scan was made at
0.5×, 1×, and 2×. The MetaPost probe was validated against a clean build of the
same S101 path translated without scaling; the translated raster matches the
probe exactly. Both the MetaPost output and Typst PDFs were rasterized through
Ghostscript at 600 ppi. Density 0.5 gives source-relative thresholded coverage
of 88.7%, 106.9%, and 94.5% at those scales. Crop RMSE at density 0.5 is
0.06988/0.05902/0.04524; the lower density 0.3 scores better RMSE
(0.06541/0.05314/0.04224) by leaving more source dots unmatched. On the
unshifted S101 plate, density 0.5 gives brush-crop coverage 0.2186% versus
0.2215% in the source and RMSE 0.05740. Density is therefore chosen for the
combined coverage and error balance, not RMSE alone. Dot phase still differs
because Typst uses a keyed stream instead of MetaPost's global random stream.
The sampled geometry remains close to the source: maximum leaf endpoint error
is 0.00009 mm and maximum leaf arc-length error is 0.000014 mm.

### Stage 4 multi-scale and seed audit

The three scan scripts below use the locked Nix devshell, the pinned upstream
source, the same Ghostscript raster flags, and decoded grayscale metrics. They
retain PDFs, PNGs, and `results.json` under `build/`:

```sh
nix develop path:./nix --command python3 diagnostics/stipple_density_scan.py --ppi 600
nix develop path:./nix --command python3 diagnostics/stipple_surface_scan.py --ppi 600
nix develop path:./nix --command python3 diagnostics/transverse_dash_scan.py --ppi 600
```

Brush density was sampled at 0.5×, 1× and 2× with four native seeds. Sphere
ring density was sampled at 0.5×, 1× and 1.5× with three seeds; tube stipple
used the same scales and seeds. The table reports ROI-mean RMSE and ink
coverage relative to MetaPost. Each cell is `RMSE / ink ratio`:

| Family and density | 0.5× | 1× | 1.5× or 2× |
| --- | ---: | ---: | ---: |
| Brush 0.50 | 0.07236 / 0.682 | 0.04963 / 0.777 | 0.03593 / 0.709 (2×) |
| Brush 0.65 | 0.07368 / 0.848 | 0.05201 / 0.972 | 0.03707 / 0.917 (2×) |
| Sphere 0.55 | 0.31288 / 0.675 | 0.33618 / 0.693 | 0.31340 / 0.716 |
| Sphere 0.65 | 0.31584 / 0.766 | 0.34109 / 0.797 | 0.31884 / 0.829 |
| Tube 0.56 | 0.18118 / 0.730 | 0.19129 / 0.751 | 0.17267 / 0.735 |
| Tube 0.66 | 0.18456 / 0.801 | 0.19461 / 0.846 | 0.17699 / 0.831 |

Higher density consistently closes the ink-coverage gap but raises pixel RMSE
for all three families, across scales and seeds. The phase and per-leaf dot
placement differences remain large enough that changing density alone is not
a demonstrated visual-fidelity improvement. Keep the current density defaults
until an algorithmic change improves both measures or is justified by reviewed
images. This also confirms the old density tuning is not scale invariant.

The transverse tube period scan compared four periods over four keyed seeds.
The 0.9 pt period averages RMSE 0.154460, dark-coverage ratio 1.002 and ink
ratio 1.004. The 0.75 pt setting averages 0.154829 / 1.006 / 1.008; 1.05 pt
averages 0.154811 / 0.995 / 0.998; and 1.2 pt averages 0.154810 / 0.985 /
0.987. The 0.9 pt adjustment remains the best balanced choice and is stable
across these seeds, though the RMSE differences are small.

A prototype that routed each sphere ring through the recursive leaf model
reduced S101 sphere-crop RMSE from 0.336538 to 0.335145 at the default density,
but lowered its ink-coverage ratio from 0.689 to 0.643. Supplying the already
sampled circle directly kept the full S101 Typst render near 12 seconds; an
earlier version redundantly resampled every circle segment and took over two
minutes for one plate. Neither version met the combined fidelity/performance
criterion, so the library change was discarded. The retained candidate report
is `build/stage4-sphere-candidate-v2/index.html`.

**Stage 4 exit:** the brush, sphere, tube stipple and transverse dash families
have been checked across multiple scales or seeds on the pinned 600 ppi
pipeline. The only consistent density adjustment trades lower RMSE for more
source-like ink coverage; no density-only change improves both. The reviewed
dash period is robust. The recursive sphere candidate did not improve the
combined fidelity measures enough to justify retaining it. Keep the current
renderer and proceed with the remaining independent differences rather than
encoding a per-plate or per-seed fit.

The same trace now covers all three S101 stipple objects. Sphere rings produce
1,930 drawable leaves, 5,790 local pattern calls, and 6,942 reconstructed
dots; the tube produces 687 leaves, 2,061 calls, and 4,067 dots. Their source
dot diameters have nearly identical ranges and means (sphere 0.26898–0.35863
bp, mean 0.31382 bp; tube 0.26912–0.35864 bp, mean 0.31462 bp). This supports
using the same per-pattern size model for all three families; the remaining
family differences lie in each path's width-driven leaf segmentation and the
number of dots allocated to its local patterns.

### S101 tube stipple density

The 29 × 28 mm S101 tube crop was rescored with both the raw MetaPost plate
and Typst PDF passed through Ghostscript at 600 ppi. Source coverage is
5.2583%; `dot-density: 0.56` gives 5.2588% and crop RMSE 0.25436. A 0.50
trial lowers RMSE to 0.24898 but underfills to 4.8519%; 0.60 raises coverage
to 5.5137% and RMSE to 0.25703. Keep 0.56 as the coverage balance. The phase
stream remains different, so pixel RMSE does not improve monotonically with
coverage.

### S101 sphere stipple density

The 26 × 26 mm S101 sphere crop was rescored with both PDFs rasterized by
Ghostscript at 600 ppi. Source coverage is 13.111%; ring density 0.55 gives
11.810% and RMSE 0.39436. Densities 0.58 and 0.60 move coverage closer
(12.284% and 12.643%) but increase crop RMSE to 0.39673 and 0.39822. The
full-plate RMSE likewise rises from 0.18317 at 0.55 to 0.18383/0.18424.
Keep 0.55 for the better pixelwise shape match; the source phase and local
dot-size distribution remain different.

### S104 flat-surface hatch row trace

The supplemental S104 fixture maps the source's +30° MetaPost hatch to −30°
in Typst page coordinates because its `P()` helper flips the vertical axis.
The corrected trace has 142 drawable rows; the instrumented source emits 143
row records including one zero-length edge row. Their physical row-length
ranges match (0.68–39.69 mm). MetaPost scans those rows in y-up order, so
`flat-surface(rng: "metapost")` traverses the Typst rows in reverse when
assigning its shared random stream. Each row requests 3–5 divisions via
`pathSubdivide` (`3 + round(uniformdeviate(2))`). MetaPost then accumulates the
requested `1/n` path-time step in 16.16 arithmetic. For requests of 3 or 5,
rounding leaves the final time just below 1, so the source emits 4 or 6 path
segments, including a very short terminal segment. `_mp-path-subdivision-times`
now reproduces those accumulated times. At 600 ppi hatch crop RMSE falls from
0.07650 to 0.07529 and whole-plate RMSE from 0.20725 to 0.20703. Hatch ink
coverage is 14.359% versus 14.066% source; full-plate coverage is 10.808%
versus 10.630% source.

Source row-level tracing counts 1516 random calls across 142 drawable rows,
including each row's subdivision draw. The initial Typst trace used 1322 calls
and matched the source count on 87 rows. Rounding widths in mm and the
dimensionless width-level ratio with separate MetaPost 16.16 quantizers raises
Typst to 1540 calls, with exact per-row brush counts on 108 rows. The new
path-time accumulation changes the knot positions inside each row but leaves
that call total unchanged. An earlier prototype applied the length quantizer
to the scalar ratio; it regressed hatch RMSE to 0.07974 and was reverted. Brush
leaf geometry and some local random calls still differ.

`instrument_flat_surface.py` also emits `S104-OUTER` and `S104-THIN` records
for each source brush recursion node on the hatch panel. `S104-CTRL` now also
records each width-path segment's knots and Bézier controls. The source
`offsetPathTemplate` connects sampled width knots with straight segments, and
the traced source knot widths match Typst after converting MetaPost points to
millimetres. This rules out an initial-knot interpolation mismatch for the
fixture. The pinned source produces 1340 `brushGenerate` nodes and 1696
`thinBrushGenerate` nodes; before cut-time rounding, Typst had 780 outer and
1577 thin nodes. Typst now rounds each recursive crossing parameter to the
source 16.16 path-time grid when `source-rounding: true`. At 600 ppi S104 hatch
RMSE is effectively unchanged (0.075286 to 0.075285), while outer nodes rise
to 942 and thin nodes remain 1577. One traced 31.180 mm row now matches the
source's 39 outer and 9 thin nodes; nearby rows still differ, so this improves
the recursion model without claiming a complete port. The remaining mismatch
is in cut selection/branch behavior around narrow residual crossings.

`S104-OFIX` records each outer node's endpoint widths, `minStrokeWidth`, and
returned cut time as 16.16 chunks; `S104-OCTRL` records compact fixed-point y
coordinates for its width-cubic controls. On row `-15.3487`, source outer
node 2 starts one 16.16 unit above `minStrokeWidth`
(`w0 = (51·256 + 3)/65536`, threshold `(51·256 + 2)/65536`) and cuts at local
path time `0.0116`. Rounding Typst's outer threshold to the source unit moves
the root cut time from `1.65510559` to `1.65519714`, closer to the source
`1.65522766`; the source-projected cut-point error falls from `0.000998` to
`0.000323 mm`. The depth-2 branch still stops because its Typst endpoint width
remains `3.4e-8 mm` below threshold, so recursive width propagation remains
open. At 600 ppi this small source-level improvement changes S104 whole/hatch
RMSE from `0.20702865/0.07528521` to `0.20702928/0.07528865`. Across matched
M4/M6/M11 renders, metrics are unchanged; M9 RMSE improves by `1.76e-6` and
S105 by `3.76e-7`. Retain the source-exact threshold despite the negligible
S104 pixelwise tradeoff; continue investigating the recursive cut width.

The new `analyze_s104_cut_intersections.py` pairs each cut with its own exact
source cubic controls and fixed-point time. For this row, source
`firstIntersectionTimes` returns `1.65522766` while the exact cubic root is
`1.65492377` (about 20 path-time units apart). On the one-unit child node it
returns `0.01159668` even though the cubic has a threshold root at the endpoint
`0`; the returned point is already below the threshold. This confirms that
the remaining branch is sensitive to MetaPost's ray-intersection and endpoint
handling, not only the ideal cubic crossing. Reproduce it with:

```sh
python3 diagnostics/analyze_s104_cut_intersections.py \
  /tmp/s104-source-trace/trace.log -15.3487
```

The instrumenter also records exact x controls (`S104-OXCTRL`) and both
horizontal ray cubics (`S104-ORAY`). These are the inputs needed to port the
source solver: MetaPost's published algorithm recursively bisects overlapping
control-point boxes, tries the four child pairs in order, and returns the
midpoint times after 17 bisections. Its returned times therefore need not equal
the mathematical cubic roots. See sections 524 and 531–537 of
[Knuth's MetaPost source manual](https://mirror.gutenberg-asso.fr/tex.loria.fr/prod-graph/mp.pdf#page=190).
The path-level search retries with overlap tolerance steps 0 and 3; the
cubic-level tolerance grows with each bisection. `replay_s104_intersections.py`
models those retries, the four-pair ordering, the 17-level midpoint result,
and Fiziko's forward/reverse selection:

```sh
python3 diagnostics/replay_s104_intersections.py \
  /tmp/s104-intersection-source/trace.log -15.3487
```

On the recorded row, the floating-point model reproduces 8 of 11 source cuts
within one 16.16 path-time unit. It still misses three cuts, including the
near-endpoint child whose source cut is `0.01159668` but whose replay remains
near the opposite side. The remaining error is consistent with MetaPost's
fixed-point packet arithmetic and endpoint fallback, which this model does not
yet emulate exactly. This is a useful localization diagnostic, not a validated
production solver; keep the renderer unchanged until the outstanding cases
are resolved. The production port still uses a sampled width crossing.

The source instrumenter now emits `S104-RAW` with both unadjusted
`intersectiontimes` results. For the endpoint child (serial 43), the ray to
the left gives direct `(0.99610, 0.00390)` and reversed `(0.98839, 1.98840)`
hits. Fiziko selects the reversed hit because its ray time is smaller, then
maps its path time back to `2 - 1.98840 = 0.01160`. This confirms the large
replay error is in MetaPost's low-level intersection choice, before
Fiziko's midpoint-nearest selection. The diagnostic prints source raw hits
alongside its own replay whenever `S104-RAW` records are present.

The source outer-node and Typst recursion logs now include centerline
endpoints and cut points, allowing exact row pairing. On one symmetric-width
row, source `cutPathTime` chooses the left of two equidistant intersections;
Typst previously chose the right due to tiny arc-length accumulation error.
With a source-mode tie tolerance, the first cut moves to within 0.001 mm of
the source cut. Aggregate node counts remain 942/1577 (source 1340/1696),
while the 600 ppi hatch crop RMSE improves from 0.075286 to 0.07528521 and
whole-plate RMSE from 0.207029 to 0.20702865. Rounding the recursive cut
width itself was retested and reverted: outer nodes fell to 814 and hatch
RMSE regressed to 0.07529141. The instrumentation records `S104-CUT` only
when the source returns an interior cut.

One source row (`traceHatchRow = -14.45174`) exposes a particularly sensitive
case in the remaining narrow-crossing mismatch. Its outer recursion accepts
ten successive cuts near the ends of the two child paths: the first moves from
`(28.24090, 10.41788)` to `(45.86412, 20.59260)`, then the left child is cut
repeatedly from `x=36.97789` through `x=36.97308` mm; the right child similarly
accumulates cuts from `x=45.86465` through `x=45.86945` mm. These are source
decisions (`S104-CUT`), not Typst artifacts. They show that tiny residual
width crossings can continue to split when the outer brush has no 0.01
path-time endpoint guard. A future candidate must reproduce this row's
recursive path-time and fixed-point behavior before using leaf counts or a
local cut match as evidence; simply accepting every flat-width crossing is
already known to overgrow the all-row tree.

A follow-up removed 16.16 rounding from each local intersection fraction while
retaining rounding of the selected whole-path parameter. This slightly lowers
hatch RMSE to 0.07528461, but the outer recursion grows to 2110 nodes (source:
1340); thin recursion remains 1577 (source: 1696). The source compares the two
midpoint-side intersections after quantizing each `firstIntersectionTimes`
hit, so local hit rounding is required even though the final selected path
time is also rounded. The experiment was reverted because its tree is much
less faithful and its raster gain is negligible.

The thin-recursion endpoint guard had also compared the source's path-time
margin (`t > 0.01` and `t < length(p) - 0.01`) against physical arc length.
An initial correction compared the quantized cut parameter in path-time units.
A follow-up source audit showed that MetaPost evaluates this condition on each
recursive subpath, whose local parameter starts at zero. The current
source-rounded guard therefore maps each cut and subpath endpoint back to
their local path times before applying the margin. This changes the traced
recursion tree without changing the S104 raster: the candidate and baseline
600 ppi Typst PNGs have identical SHA-256 hashes, and both report whole-plate
RMSE `0.20702865` and hatch RMSE `0.07528521`. The previous global-parameter
guard trace below remains useful as a historical comparison, not as the
current local-guard node count. For the earlier global-parameter guard, a
regenerated, endpoint-paired trace matched all 142 source hatch rows to Typst
rows within 0.0015 mm. In that earlier global-parameter implementation,
aggregate outer recursion decisions moved from 942 to 1270 (source: 1340),
and thin decisions from 1577
to 1739 (source: 1696); all 142 rows pair by endpoints with maximum summed
endpoint error 0.0015 mm, and 80 rows now have exact outer/thin node counts. The
S104 PDF pixel hash and RMSE remain unchanged (`0.20702865` whole plate,
`0.07528521` hatch). M4 and M6 render hashes also match their existing source-
boundary candidates. M9 RMSE changes from 0.213280 to 0.213294; S105 changes
from 0.103042 to 0.103137 (block 0.128378 to 0.128550, surface unchanged at
0.078508). These are small raster regressions from applying the source's
path-time guard consistently in the shared brush core. The source-aligned
recursion decision counts improve in S104; the 142 hatch rows still consume
1540 modeled random calls against 1516 in MetaPost.

`instrument_flat_surface.py` now emits compact `S104-SEG` endpoint records and
the actual requested `pathSubdivide` count in `FSSUB`, so rows can be paired
independently of scanline order and subdivision count can be separated from
downstream brush-call drift. On the first row whose random-call totals differ,
both sides request three subdivisions and source/Typst cut positions agree to
about 0.001 mm, but the source consumes 11 brush random calls and Typst 7. The
remaining four-call gap therefore lies in thin-brush leaf/dash decisions, not
the row's subdivision draw or outer cut geometry.

Rounding each S104 width-template sample to MetaPost's 16.16 millimetre grid
left the 142 row call counts unchanged (108 exact source-row matches; 34
mismatches, with per-row deltas up to ±20 calls). It slightly regressed the
600 ppi whole/hatch RMSE from 0.207029/0.075286 to 0.207041/0.075353. That
prototype was reverted. The follow-up trace shows that source and Typst width
knots already agree for the fixture after unit conversion; the more useful
numerical difference is the recursive crossing parameter. Quantizing that
parameter improved aggregate outer-node counts, but remaining mismatches are
concentrated around narrow residual crossings and in cut selection.

A follow-up also quantized the interpolated width at each recursive cut. This
reduced Typst outer-node records from 942 to 870 (source: 1340), while thin
nodes stayed at 1577 (source: 1696). The recursive tree moved farther from the
source, so this candidate was reverted before raster comparison. Fixed-point
rounding belongs at the source's returned path-time boundary here; applying it
again to the interpolated width does not reproduce MetaPost's cut semantics.

The row-level Typst trace is `flat_surface_hatch_trace.typ`. To instrument the
pinned source without changing its lock-verified snapshot, use a copy inside
the Nix devshell:

```sh
mkdir -p /tmp/s104-source-trace
python3 diagnostics/instrument_flat_surface.py \
  "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/s104-source-trace/fiziko.mp
cp comparisons/reference/supplemental.mp /tmp/s104-source-trace/
printf 'selected := 104; input supplemental.mp;\n' \
  > /tmp/s104-source-trace/trace.mp
(cd /tmp/s104-source-trace && \
  mpost -interaction=nonstopmode -halt-on-error -jobname=trace trace.mp)
rg 'FSROW' /tmp/s104-source-trace/trace.log
rg 'S104-(OUTER|OFIX|OCTRL|OXCTRL|ORAY|RAW|THIN|TNODE|TDASH|HIT|WFIX|TKNOT|TCTRL|TXCTRL|TENTRY|TRAY|FIRST(-FIX)?)' /tmp/s104-source-trace/trace.log
typst eval 'query(<s104-hatch-rows>).first().value' \
  --in diagnostics/flat_surface_hatch_trace.typ --root .
```

On row 93 (`y=-6.37912`), rebuilding q x knots from fixed-point cubic arc
lengths of the sampled straight segments does not change the q-candidate tree:
it remains 11 outer / 9 thin nodes and 4 dash leaves, versus source 21 / 19 / 5.
The source root q knots are `0, 2298558, 4597113, 6895671, 6895777` in 16.16
bp; the Typst line-arc reconstruction gives
`0, 2298550, 4597100, 6895650, 6895754`, ending 23 units short. This residual
comes from the scanline segment endpoints: after the source page's vertical
flip, paired endpoint coordinates differ by about 0.0001–0.0002 mm.
Fixed-point arc arithmetic alone
does not correct that geometry. The experimental q injection was removed; the
row's fixed-arc knots remain in its metadata for follow-up endpoint mapping.

The source instrumenter also emits unique `S104-TNODE` endpoint IDs and
`S104-TDASH` markers. On row `-6.37912`, these pair all five source dash leaves
with three Typst dash-eligible leaves. The first divergent width cut belongs
to the same depth-4 path on both sides: source cuts at x=39.539 mm, Typst at
x=44.895 mm. The source width base/step/target (0.06642/0.00830/0.15773 in
MetaPost units) match Typst after unit conversion. A fresh row-93 probe now
records both ordinary and `width-by-arc` recursion trees. Both Typst modes
produce 17 thin nodes and 3 dash leaves; the source trace has 19 thin nodes and
5 dash leaves. The first divergent cut remains x=39.539 mm in MetaPost versus
x=44.895 mm in Typst, so arc-length interpolation does not explain this
branch. The diagnostic's `arc-width-nodes` and `arc-width-calls` fields are
populated only for row 93. Treating quantized flat segments as crossing
intervals increased total Typst thin nodes from 1739 to 3259 (source: 1696),
so that candidate was reverted. A source trace now links every thin-node ID
to its template knots, cubic controls, and `cutPathTime` hit pair. At the first
divergent parent, source node 172, `w2` and the middle knot are exactly
10337/65536 pt. The next cubic segment's control/end widths are 10337, 10337,
10336, 10336 in that grid. Its midpoint is a one-unit tie; MetaPost's
`cutPathTime` trace selects that midpoint-side hit (q time 1.50017, x=52.61568)
over the other hit (q time 1, x=35.07321). This maps to the page-space cut
x=39.539 mm. Typst's sampled width polyline chooses x=44.895 mm. The following
child, source node 173, shows the same behavior again at a nearby midpoint:
its 16.16 cubic value before rounding is 10336.546…, and its source hit has q
time 1.469 at x=43.3005. That child cut is separate from the parent cut above.
The specific behavior to port is the source width template's `--` cubic
controls, 16.16 point evaluation, and intersection behavior through recursive
subpaths. Arc-length interpolation alone cannot reproduce this branch.

The thin trace now captures the exact ray cubics (`S104-TRAY`) and the two
raw MetaPost `intersectiontimes` pairs (`S104-FIRST`) used by
`firstIntersectionTimes`. The trace records `cutPathTime`'s hit times and x
coordinates separately to avoid MetaPost transcript line truncation. On node
172, the first ray's raw pair is `(0, 1.50017)` and `(0.9411, 0.99817)`; the
source macro selects the first pair because its ray time is smaller. The
second ray's pair is `(0.9416, 1)` and `(0.9416, 2)`; its tie selects the
reversed-path result, mapped back to path time 1. The midpoint-distance test
then selects `1.50017`, at x `52.61568`, over x `35.07321`. The new replay
script reproduces both source stages for all 19 recorded cuts on this row:

```sh
python3 diagnostics/replay_s104_thin_intersections.py \
  /tmp/s104-thin-ray-replay/trace.log -6.37912
python3 diagnostics/replay_s104_thin_intersections.py \
  /tmp/s104-thin-ray-replay/trace.log -6.37912 --node 172
```

This closes the source-side decision trace, but not the port. At this point the
Python bisection model was superseded by the fixed-point packet replay below;
the production Typst path still uses width crossings on sampled segments and
selects the other midpoint-side cut at x `44.895` mm. Do not infer a production
change from source replay alone: pair recursive subpath controls and validate
the cut choice in the full render before retaining a renderer change.

The thin replay includes an integer first-difference packet model of
MetaPost's cubic search. It uses 16.16 controls, the four ordered child pairs,
source-style tolerance updates, the packed `max_t` frontier, best-pair
fallback, packet-stack limit and final 16.16 path-time conversion
([source](https://github.com/TeX-Live/texlive-source/blob/branch2025/texk/web2c/mplibdir/mp.w#L15000-L15149)).
The crucial branch rule is in `NOT_FOUND`: moving from left-left to left-right
adds the current `three_l` to `tol`; moving to right-left retains that value;
moving to right-right adds it once more. The old recursive replay passed one
tolerance to all four pairs and matched only 67/76 target-row cases. With the
branch-specific values, it matches all 76/76 raw pairs within one 16.16 time
unit, including the former endpoint and interior misses.

The fresh source trace contains 62 rows, 6,784 raw direct/reverse hit pairs,
and 1,696 wrapper cut decisions; the corrected replay matches every pair and
decision. The earlier wrapper mismatches came from returning before applying
`firstIntersectionTimes`' direct-miss override and from comparing rounded
five-place hit positions; the current trace includes fixed-point hit positions
and cut times. On the focused row, the depth sweep
15–23 and four half-rounding variants all remain 76/76. The wrapper-level
replay independently reproduces all 19/19 selected cut decisions. The reduced
M11 coast endpoint probe also matches all 17 source sweep values. These are
diagnostic results only: production `split-path` still finds crossings by
linear interpolation and midpoint arc distance. The packet search and
`firstIntersectionTimes` wrapper are now also implemented in Typst as the
standalone internal module `intersection.typ`. A focused Typst fixture checks
the four raw pairs from S104 node 172 and the 17 M11 endpoint levels against
the source traces; all match within one fixed-point unit. Run it with:

```sh
nix develop path:./nix --command python3 \
  diagnostics/check_typst_intersection_fixtures.py \
  /tmp/m11-endpoint-probe/probe.log
```

An opt-in trial reconstructed width cubics from sampled frames and routed the
row-93 `split-path` probe through this solver. Its tree had 16 decisions and 3
dash leaves, compared with 24 decisions in the current Typst row probe and 40
source decisions with 5 dash leaves. Since the recursive tree moved farther
from the source, that `split-path` integration was reverted; the standalone
solver and fixtures remain. The missing information is the exact source
width-template subpath and its parameter mapping through repeated cuts. The
next step is to carry those cubic controls alongside recursive path nodes,
then validate the complete S104 and M11 trees and renders before enabling the
solver in production.

`S104-FIRST-FIX` preserves the raw source intersection times as signed 16.16
chunks; older decimal-only logs remain supported. `audit_s104_fixed_encoding.py`
checks the paired source controls, rays and time values against the five-place
decimal trace so input conversion remains separately verifiable.

`audit_s104_fixed_encoding.py` checks that the recorded base-256 controls,
ray endpoints and raw intersection-time pairs decode consistently with their
five-decimal source companions. On the fresh target-row trace it checks 132
cubic controls, 76 ray endpoints and 38 raw-hit pairs; maximum differences are
`7.28e-6`, `6.59e-6` and `6.81e-6`, respectively. This does not prove the
packet overlap arithmetic, but rules out a large mismatch in trace decoding.
Run it with:

```sh
nix shell nixpkgs#python3 --command python3 \
  diagnostics/audit_s104_fixed_encoding.py \
  /tmp/s104-fresh/trace.log -6.37912
```

To reproduce the full-trace result:

```sh
nix shell nixpkgs#python3 --command python3 \
  diagnostics/compare_s104_all_intersections.py \
  /tmp/s104-fresh/trace.log
nix shell nixpkgs#python3 --command python3 \
  diagnostics/compare_m11_endpoint_intersection.py \
  /tmp/m11-endpoint-probe/probe.log
```

For a detailed focused-row report:

```sh
nix shell nixpkgs#python3 --command python3 \
  diagnostics/replay_s104_thin_intersections.py \
  /tmp/s104-thin-ray-replay/trace.log -6.37912
nix shell nixpkgs#python3 --command python3 \
  diagnostics/replay_s104_thin_intersections.py \
  /tmp/s104-thin-ray-replay/trace.log -6.37912 --node 172 --verbose
```

This narrows the source solver work but does not validate a Typst rendering
change. The low-level algorithm now exists in Typst, but the sampled-frame
integration failed the row-tree comparison and was reverted. Rounded-cubic
production candidates still regress the whole S104 render; keep the renderer
unchanged until recursive width-template controls are carried exactly and a
full-row comparison improves both recursion decisions and the paired hatch
image.

`s104_node_172_q_replay.typ` is a focused trace-driven check of that missing
state. It feeds the exact source 16.16 width q cubics and the matching three
centerline segments from row `-6.37912`, node 172, into `_ink-loops`' existing
q-state path. Typst selects q time `1.5001678467` and cuts at x `39.53915 mm`,
matching the source's q time `1.50017` and x `39.539 mm` within 0.00016 mm.
The following recursive left child also reaches q time `1.468994`, matching
the source's logged `1.469` to the 16.16 grid. This verifies that exact q
controls plus their one-to-one centerline segment map recover the troublesome
local cuts. It does not show how to reconstruct that q state from the row's
initial scanline samples, nor does it establish full-row tree or raster
improvement. Run the fixture with:

```sh
nix develop path:./nix --command typst eval \
  'query(<s104-node-172-q-replay>).first().value' \
  --in diagnostics/s104_node_172_q_replay.typ --root .
```

The source trace now also emits `S104-PCURVE` for the target row's recursive
thin paths. At node 172, the path's page-space cubic is straight within each
segment, but the node contains a short first segment, a long middle segment,
and a short final segment. The middle segment runs from `(34.17966, 17.13503)`
to `(44.89505, 23.32155)` mm with controls at its one-third and two-thirds
points. Its associated width cubic has controls `0.15773, 0.15773, 0.15771,
0.15771` mm. Source `cutPathTime` selects q time `1.50017`, which maps to the
middle of this long segment at page x `39.539` mm. The current Typst tree
reaches the same node endpoints but cuts at x `44.895` mm, the middle segment's
end. This rules out a centerline curvature explanation for this mismatch and
narrows the next implementation probe to preserving the source q cubic's
parameterization and fixed-point intersection through recursive subpaths. The
upstream hatch width law explicitly uses `offsetPathLength`; the Typst trace
evaluates the same law over normalized cumulative path length with
`_path-fractions`. Their row-knot widths agree after unit conversion, so
replacing arc-length width interpolation with path-time interpolation would
not address this cut.

A second probe applied the rounded source cubic only to thin-recursion cuts,
leaving the already matching outer cuts unchanged. On row 93 it moves node
172's cut to x=39.537 mm, within 0.0017 mm of the source's x=39.539 mm, and
reaches 19 thin nodes on that row. Across all hatch rows, however, thin nodes
fall from 1577 to 1490 (source: 1696), thin leaves from 819 to 776, and dash
calls from 699 to 668. The 600 ppi render also regresses: whole S104 RMSE
0.207029 → 0.207733 and hatch crop RMSE 0.075285 → 0.079011. This candidate
was reverted. The matched node is a useful local oracle, but reproducing it
alone does not establish a better brush tree across rows.

The source centerline trace hook has since been widened to capture every
recursive path segment on this row; its prior `traceThisThin >= 172` filter
missed node 164 after the trace serials changed. A fresh source/Typst pair
confirms that the source's node 172 width segment has fixed-point controls
`10337, 10337, 10336, 10336` at threshold `10337`. A Typst fixed-point cubic
evaluator selects x=39.537 mm, matching the source x=39.539 mm at that cut.
Applying the evaluator across all width segments yields 1692 Typst thin nodes
(source 1696) but regresses 600 ppi RMSE from `0.207029`/`0.075285` to
`0.207368`/`0.077099` (whole/hatch); total brush calls are 1554 versus 1516
source. A narrower evaluator, activated only when the threshold equals a
rounded cubic control, yields 1524 thin nodes and 1494 calls, with whole/hatch
RMSE `0.207325`/`0.076870`. Both production candidates were reverted: matching
the one midpoint tie does not yet preserve the source tree across its recursive
subpaths and rows.

### S104 fixed-point scanline endpoint probe

`probe_s104_fixed_scanline.py` independently reconstructs a hatch row using
MetaPost-style 16.16 rotation, half-open polygon crossings, fixed-point
intersection parameters, and interpolation. For source row `-6.37912`, its two
page-space endpoints match the source trace within 0.000003 mm and 0.000011 mm.
The source mechanism is therefore recoverable locally. A production prototype
using these crossings reduced the row's root q-knot residual from 23 to 7
16.16 units, but did not improve the complete recursion: across 142 paired
rows, exact row matches changed from 108 to 107 and RNG-call L1 error from 332
to 422. At 600 ppi, whole/hatch RMSE regressed from 0.207029/0.075285 to
0.207417/0.077360. Adding generated q knots recovered only to
0.207407/0.077308. The prototype was removed from production. The remaining
S104 task is to carry row scheduling, recursive center-path parameterization,
and q controls together, then pass both tree and image gates.

A further diagnostic supplied each subdivided Typst vertex width to
`_ink-loops` as a source-rounded 16.16 q-template knot, letting it rebuild q
abscissae from the row's polyline arc. On the Typst row paired to source row
93, this changes the thin tree from 10 nodes/9 dash leaves to 5/3; the source
has 19 nodes/5 dash leaves. The q-knot injection therefore moves the tree
farther from source and was discarded. Width samples alone are insufficient:
the row's source scanline schedule, q-curve controls and recursive path-time
mapping must be carried together.

That trial preceded the fixed-point q-width span gate in `_ink-loops`. With
the span compared in integer 16.16 units, repeating the same production-width
q-knot injection gives 19 thin nodes and 5 dash leaves on row 93; all 19
source thin-node endpoints are within 0.00054 mm, and all recurse/stop and
dash decisions match. The source exact q-curve replay and generated-width
replay both cut the critical branch at q time `1.5001678467`; the following
node's 544-unit span equals its 544-unit step and now correctly recurses.
Despite that exact row tree, injecting generated q knots into production
regresses 600 ppi S104 whole/hatch RMSE from `0.20703985/0.07534579` to
`0.20743547/0.07745702`. The renderer injection was reverted; keep the
diagnostic as a local recursion oracle while resolving page-wide scanline and
q-template mapping.

Run the endpoint probe with the project toolchain:

```sh
nix develop path:./nix --command python3 \
  diagnostics/probe_s104_fixed_scanline.py /tmp/s104-fresh/trace.log
```

A diagnostic-only port of that cubic model was tried after the trace above.
It used the original global cubic controls with 64 subdivisions per Typst path
segment, then bisected candidate threshold crossings. It did not reproduce the
source cut: in the row-93 tree the source's depth-4 cut is at x=39.539 mm,
while this candidate's nearby cut is x=44.502 mm. It yielded 15 thin nodes and
13 dash-eligible leaves, versus 19 and 5 in the source. The candidate was
removed before raster comparison, so these counts do not establish a visual
regression; they show that dense sampling and bisection over the current
Typst parameterization do not model MetaPost's recursive subpath intersection.
Do not reintroduce this approximation without first pairing source and Typst
parameter intervals and their cubic control points.

An earlier prototype split at every sampled width threshold and did not
reproduce the source's recursive branch gates. It was superseded by the model
above. A separate test of per-dot independent phases was also worse than
paired phases, so the open-path model restarts paired patterns at each
quantized leaf instead.

Leaf arc lengths do not support one fixed size-correlation interval across the
families. The brush median is 0.916 mm (mean 0.913 mm), the sphere median is
0.661 mm (mean 0.887 mm), and the tube median is 1.163 mm (mean 1.725 mm).
Sphere and tube leaves also include unusually long spans where the width
profile stays above the recursion threshold. A reusable model should follow
the width-driven split rule instead of substituting a fixed-length block.

Generate the instrumented source and run the focused MetaPost driver:

```sh
project=$PWD
python3 diagnostics/instrument_brush.py "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/fiziko-s101-brush-trace.mp
typst eval 'query(<s101-centerline>).first().value' --in diagnostics/s101_brush_trace.typ --root . > /tmp/s101-typst-centerline.json
cd /tmp
mpost -interaction=nonstopmode -halt-on-error -jobname=s101-brush-trace "$project/diagnostics/s101_brush_trace.mp" > /tmp/s101-brush-trace.stdout
python3 "$project/diagnostics/compare_brush_trace.py" /tmp/s101-brush-trace.log /tmp/s101-typst-centerline.json
```

MetaPost writes its transcript to `/tmp/s101-brush-trace.log`; stdout goes to a
separate file so the two writers cannot overwrite one another. Count markers
or extract leaf records from the transcript, not from the PostScript figure.

To trace the complete S101 brush, sphere, and tube plate, use the shared
instrumenter and the all-object driver:

```sh
project=$PWD
python3 diagnostics/instrument_brush.py "$FIZIKO_UPSTREAM_PATH/fiziko.mp" /tmp/fiziko-s101-stipple-trace.mp
cd /tmp
mpost -interaction=nonstopmode -halt-on-error -jobname=fiziko-s101-stipple-trace "$project/diagnostics/s101_stipple_trace.mp" > /tmp/fiziko-s101-stipple-trace.stdout
python3 "$project/diagnostics/summarize_stipple_trace.py" /tmp/fiziko-s101-stipple-trace.log
```

MetaPost stores the transcript separately from stdout. The summary counts
draw-enabled leaves and reconstructs dots from each local dash phase; its
diameters are in MetaPost's bp coordinate units.

### Uniform RNG checkpoint

With MetaPost 2.11 from TeX Live 2025, a standalone
`randomseed := 1; show uniformdeviate(1)` probe returns
`0.25172, 0.39517, 0.25339, 0.06187` for its first four draws. The seed
assignment passes the number through `number_to_scaled`, so the generator is
initialized with 65536. The published lagged-Fibonacci setup uses a 30-bit
modulus, lags 100/37, ten warm-up arrays, then fills a 1009-value buffer on
first use ([TeX Live RNG implementation](https://github.com/TeX-Live/texlive-source/blob/trunk/texk/web2c/mplibdir/mpmathbinary.w),
[seed assignment](https://github.com/TeX-Live/texlive-source/blob/trunk/texk/web2c/mplibdir/mp.w)).

A standalone C transcription of that recurrence still does not match the
runtime: its first output is `0.28035307` with seed 1 and `0.05092263` with
seed 65536. This mismatch means the Typst implementation must not claim
MetaPost random-stream compatibility. Keep the current deterministic keyed
RNG unless a comparison proves a visual improvement from another model.
