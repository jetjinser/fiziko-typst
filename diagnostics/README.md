# Figure 12 latitude comparison

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

To regenerate the comparison from an upstream `fiziko.mp`, make a diagnostic
copy and run the included MetaPost and Typst drivers:

```sh
nix shell nixpkgs#python3 -c python3 diagnostics/instrument_metapost.py /path/to/fiziko.mp /tmp/fiziko-diagnostic-source.mp
mpost -interaction=nonstopmode diagnostics/figure12_diagnostic.mp > /tmp/figure12-mp.log
typst eval 'query(<traces>).first().value' --in diagnostics/figure12_trace.typ --root . > /tmp/figure12-typst.json
nix shell nixpkgs#python3 -c python3 diagnostics/compare_latitudes.py /tmp/figure12-mp.log /tmp/figure12-typst.json /tmp/figure12.csv
```

The two checked-in CSV files record the state before and after keeping the
original knots. The source run used jemmybutton/fiziko's `fiziko.mp` with
MetaPost 2.11 and random seed 1.
