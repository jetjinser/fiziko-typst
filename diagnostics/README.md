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
the option is deliberately restricted to longitudinal tubes. Variable-radius
boundary-lane calls and source-exact subdivision still need tracing before
this can stand in for a complete tube RNG port.

The pinned `tubeGenerate` loop includes both boundary lanes (`k=0` and
`k=bw1`). A direct M4 pilot drew those tracks using the current sampled offset
geometry; this raised ink coverage from 1.751% to 1.835% against 1.789% source
and regressed RMSE from 0.07025 to 0.07031, so the added strokes were removed.
Consuming their Typst brush results while suppressing the marks produced the
same M4 pixel hash as before, so those boundary paths consume no dash calls in
this constant-radius fixture. Matching the source marks requires better
boundary geometry; variable-radius boundary-call behavior remains open.

## WoodBlock source-field pilot

`wooden-thing(..., source-field: true)` and `wood(..., source-field: true)`
sample the upstream knot-warped `wField` at the 0.2 mm detail scale. The
current Typst contour grid is 1 mm; source `woodBlockRes` is 1/3 mm. The field
includes the source's elliptic knot distance, radial well, far-field decay,
per-column offset and low-frequency perturbation. Field offsets now consume
one random value per 1/3 mm source column rather than once per millimetre.
Landscape blocks use the source's internal axis swap. A pinned-source trace
shows that each accepted knot's five brush rings consume 28 random values;
the Typst stream now advances by that amount. In M9, the first accepted knot
matches its source position within 0.1 mm. Exact source panel-end call counts
are 1456, 2823, 4120 and 5416, so Typst now starts the four panels at offsets
0, 1456, 2823 and 4120. M9's 600 ppi whole-plate RMSE falls from 0.22456 to
0.22407, with 4.224% ink coverage (source 4.203%). The 1/3 mm random-column
correction changes M9 from 0.22412 to 0.22407; S105 moves from 0.09792 to
0.09852 (block 0.12161, surface 0.07655). Source-scaled 16.16 threshold
rounding subsequently lowers the current S105 comparison to 0.09837 (block
0.12142, surface 0.07644). Source contour-brush shapes remain approximate;
see the measured per-cell brush mode below.

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

`contour-brush: "cell-range"` now applies the `cLine` width law on source-field
wood. `_woodblock-field` stores the source field divided by `rho = 1/24` so
levels are one unit apart; `cLine` computes its width from the unnormalized
cell range, so the brush calculation multiplies that range back by `rho`.
This is opt-in because the same law improves S105 but regresses M9: with the
continuous path mode, 600 ppi S105 RMSE falls from 0.10555 to 0.09792 (block
0.12095, surface 0.07598), while M9 rises from 0.22411 to 0.24644 and ink
coverage rises from 4.224% to 4.432%. S105 surface ink is 0.510% versus 0.489%
in the source. Width scaling alone is not enough; source `cLine` traversal
order, width interpolation and global dash-call phase remain relevant.

A pilot that linearly interpolated cell ranges between adjacent geometric
contour segments attempted to model `v[st]` interpolation. It regressed S105
600 ppi RMSE from 0.09792 to 0.09898; block and surface crops regressed from
0.12095 to 0.12250 and 0.07598 to 0.07648. The pilot was reverted. Geometric
segment order is not a reliable substitute for `cLine`'s recursive `st`
sequence, so the next width-law change needs a source traversal trace.

`instrument_wood_contours.py` now records the first source `cLine` traversal's
`(i, j, st, cell-range, direction)` values. For M9 the first visits begin
`(0,12,0)`, `(0,13,1)`, `(1,13,2)`, `(1,14,3)` and continue for 19 cells;
`st` rises and falls according to the recursive walk, rather than a simple
row or geometric-segment order. A 1/3 mm contour-grid pilot, combined with the
source-rate random-column offsets, increased ink coverage and regressed M9 to
0.22506 and S105 to 0.13050. That pilot was reverted; field sampling, level
selection and contour stitching need to be aligned together.

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
```

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
typst eval 'query(<m9-wood-knot-trace>).first().value' \
  --in diagnostics/wood_knot_trace.typ --root .
```

`WKCAND` coordinates are MetaPost units; divide by `72/25.4` to convert them
to millimetres. The final field reports output-space coordinates in millimetres.

## M11 coastline lightness

The coast brush now uses the upstream `sphereAnglesToNormalVector` and
`normalVectorToLightness` law: it reconstructs the spherical normal from the
projected point's azimuth and radius, then applies the normalized source light
vector. At 600 ppi, globe ink coverage moves from 25.12% to 25.21% against
25.94% source, while the globe crop RMSE changes from 0.19545 to 0.19720 and
whole-plate RMSE from 0.12622 to 0.12662. This is a source-equation match with
a small raster-score regression; the remaining latitude width law and coast
random phase are still approximate.

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
That candidate was reverted. Matching the stream start alone is insufficient;
the coast brush must also reproduce the source recursion's per-coast call
consumption before later coast phases can align.

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

Rounding each S104 width-template sample to MetaPost's 16.16 millimetre grid
left the 142 row call counts unchanged (108 exact source-row matches; 34
mismatches, with per-row deltas up to ±20 calls). It slightly regressed the
600 ppi whole/hatch RMSE from 0.207029/0.075286 to 0.207041/0.075353. That
prototype was reverted; the call-count differences cluster in the
variable-width middle rows, so the next useful trace is the source width
template's knot values and recursive cut positions.

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
typst eval 'query(<s104-hatch-rows>).first().value' \
  --in diagnostics/flat_surface_hatch_trace.typ --root .
```

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
