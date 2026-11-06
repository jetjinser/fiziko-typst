# Visual regression

Enter the pinned environment with `nix develop path:./nix`. It supplies Typst
0.15.1, Python, ImageMagick and a fixed DejaVu font path. Tests ignore system
fonts, use Typst's embedded fonts plus that path, and compare decoded pixels
exactly. PNG metadata and compression changes do not fail the check.

```sh
./check.sh                                    # PDF + geometry + harness + all snapshots
./visual-regression.sh                       # all 11 snapshots
./visual-regression.sh --case brush           # one family
./visual-regression.sh --case stipple-brush --case stipple-tube
```

`build/check/main.pdf` and `build/check/geometry.json` are the checked specimen
and numerical metrics. `build/visual/summary.json` records each visual case's
status and rendering time. Each case keeps `actual.png` and `render.log`;
failures against an existing reference additionally keep `diff.png`,
`comparison.png` and `comparison.json`. The comparison image shows reference,
actual and red pixel differences from left to right. All selected cases run
even when an earlier case fails. Exit 0 means every selected case passed;
exit 1 means at least one failed; CLI/environment errors use exit 2.

## Coverage

The ten core plates are independent branches in `core.typ`, rendered at
200 ppi on a fixed 120 × 62 mm page (945 × 489 px). They contain no labels or
prose, so typography and caption reflow cannot mask a drawing change. Seeds
and geometry are fixed; these fixtures protect current Typst behavior and do
not measure fidelity to upstream MetaPost output.

| Case | Behavior protected |
| --- | --- |
| `brush` | Literal 3 pt sin² profile, acute bend, short hairline, closed variable-width seam |
| `sphere-concentric` | Concentric ring shading, two sizes and light directions |
| `sphere-latitude` | Two projected latitudes, using the 180-sample library default |
| `tube-longitudinal` | Constant-radius curved tube, lane shading and open caps |
| `tube-variable` | Oscillating closed tube, changing lane counts and taper to zero |
| `tube-transverse` | Curved transverse sections and cross-section lighting |
| `stipple-brush` | Open brush, sparse one/two-dot pattern and closed tracks composed together |
| `stipple-sphere` | Concentric stipple tracks and silhouette |
| `stipple-field` | Alternative 2D stipple field |
| `stipple-tube` | Curved constant radius and sloping variable radius stipple tracks |

`figure-11-page-5` retains the full A4 page at 130 ppi (1075 × 1520 px),
including document pagination and the globe, eye, knot and refraction figure.
The [2026-11-02 review](reviews/2026-11-02-page-5/README.md) explains the first
baseline refresh and retains the historical comparison evidence. The
[2026-11-07 review](reviews/2026-11-07-source-fidelity/README.md) records four
later source-fidelity baseline updates.

## Reviewing an intentional change

1. Run the affected cases normally. Read their render logs and inspect the
   actual, difference and comparison images. Check the broader specimen when
   the change affects shared drawing code.
2. Explain the intended change in the commit. Update only reviewed cases:

   ```sh
   ./visual-regression.sh --case brush --update
   ```

3. Run `./check.sh` and review the Git diff before committing references.

`--update` requires explicit `--case` selections and never updates a reference
when rendering fails. A normal run cannot create or modify references. Missing
references, changed dimensions and any nonzero pixel difference fail.

## Harness checks and the composition regression

`python3 -m unittest discover -s visual -p 'test_*.py'` tests real PNG equality
despite metadata changes, a one-pixel change, resized and invalid images,
missing references, renderer errors, explicit updates and collecting reports
after failure.

The initial core-plate review exposed an unplaced open stipple-brush fill:
the first brush consumed flow space and displaced the next brush vertically.
The public primitive now wraps that fill in `place(top + left, ...)`, like
the other drawing primitives. `verify.typ` measures a nonempty sparse brush
and asserts zero flow width/height. The assertion was verified to fail with
the pre-fix library and pass with the fix. The composed `stipple-brush`
snapshot additionally protects the visible placement.

Numerical checks also enforce arrowhead endpoint/base/axis constraints,
angle-mark radius/endpoints and chord error, spring endpoints/radius/extent,
convex and concave lens extents, and both pulley quadratic residuals. The
angle-mark chord tolerance is 0.002 mm; exact geometric constraints use
1e-10. Historical metrics for the unused `_weight-parts` helper remain
reported, but are not treated as verification of the public weight renderer.
