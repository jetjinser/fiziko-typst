# Reproducible upstream comparisons

This workflow measures the current port against the unmodified fiziko
`54a63dba8e6700a5e70d3508838edebcbf0f45fe` source. Nix locks both that source
and the renderer packages. Nothing is read from `original/` or from old
files in `/tmp`. No upstream code is vendored into this Git repository.

## Run from a fresh checkout

```sh
nix develop path:./nix
./compare.sh                                 # 20 paired plates, both modes, 600 ppi
./compare.sh --case M2 --case M4               # selected pairs
./compare.sh --case M2 --mode nominal         # shared nominal inputs
./compare.sh --case M2 --mode calibrated      # documented visual adjustments
./compare.sh --case M2 --ppi 150              # fast preview, not a 600 ppi score
./compare.sh --source-only                   # all 19 historical source plates
./compare.sh --source-only --case S104        # a reference-only family
./compare.sh --list                          # available cases; no rendering
```

Alternatively use `nix develop path:./nix --command ./compare.sh ...` without
entering an interactive shell. The first invocation may fetch Nix packages
and the fixed upstream input. The Python pipeline itself does not use the
network. It verifies `fiziko.mp`'s SHA-256 before rendering and refuses an
upstream revision inconsistent with `nix/flake.lock`.

The report opens as a local file at `build/comparisons/index.html`. It links
to the source PDF, Typst PDF, source raster, Typst raster and amplified
difference for each pair. `summary.json` contains machine-readable scores,
parameters, physical crops and provenance. `--output` chooses a different
report directory; it does not change the measurement grid.

Each invocation creates a new `run-*` directory under that output. It keeps
an input snapshot, the upstream source and its license, MetaPost outputs,
PDFs, rasters and logs. Old outputs cannot accidentally satisfy a new build.
The top-level HTML/JSON index refers to the latest invocation; each run also
retains its own summary JSON. All of this lives under ignored `build/` by
default and is separate from the checked-in visual regression baselines.

## Cases and the two modes

The tracked `reference/main.mp` driver preserves **M1–M11**, and
`reference/supplemental.mp` preserves **S101–S108**. Every plate independently
resets the source seed to 1. In the old supplemental gallery only the first
plate reset its seed, so S102–S108 can have different random patterns from
historical PDFs. The new behavior makes individual builds independent of
which earlier plates were rendered. M9/S105 retain the explicit 1 mm wood
grid setting; the upstream library itself is unmodified.

Paired measurements cover all 19 historical source plates (M1–M11 and
S101–S108), plus the isolated sphere C1. The new M8–M11 and S102–S108 pairs
use source dimensions and control points where the port exposes a corresponding
primitive; algorithm and API differences are recorded in the manifest and
report. M11's eight coast paths are converted from the pinned source's
longitude/colatitude data and retained in `globe-coasts.typ`; regenerate that
file with:

```sh
nix develop path:./nix --command python3 comparisons/extract-globe-coasts.py comparisons/globe-coasts.typ
```

New pairs currently use the same inputs in both modes, with no per-plate calibration.
See [the fidelity work plan](fidelity-plan.md) for the 600 ppi baseline and
ranked follow-up work.

| Case | Subject | Calibration relative to nominal |
| --- | --- | --- |
| M1 | Open curve and variable offset | None |
| M2 | Variable-width brush | 3 pt sin² → 7.5 pt sin; sampling 24 → 96 |
| M3 | Two latitude spheres | Typst seed 1 → 15; both keep 360 samples |
| M4 | Longitudinal curved tube | Maximum shading width 0.300 → 0.308 TeX pt |
| M5 | Suspended concentric sphere composite | Sphere seed 1 → 14; tube stays at 1 |
| M6 | Variable-radius closed tube and taper | Typst seeds 1 → 12 |
| M7 | Transverse tube | Dash period 1.2 → 0.9 TeX pt; both keep `per: 384` |
| C1 | Isolated 26 mm concentric sphere | None; avoids M5's tube and annotations |
| S101 | Stippled brush, sphere and tube | No extra override; retains current density defaults |
| M8–M11 | Pulley composites; wood; mechanics; globe/eye/knot/optics | None; both modes use the source-mapped nominal inputs |
| S102–S108 | Tube/shadow; fills; flat surfaces; wood; weights; wheels; lenses | None; both modes use the source-mapped nominal inputs |

**Nominal** matches the shared physical inputs, source seed number and width
law wherever the APIs admit a direct mapping. It is not a promise of equal
algorithms, path subdivision, random sequences or pixel output. Source
MetaPost uses a global RNG; Typst's keyed randomness is different even with
seed 1. Existing library defaults include earlier visual calibrations:
S101's 0.5/0.55/0.56 density multipliers are native settings, not corresponding
upstream parameters. Native dash/arrow/label construction can also differ.

**Calibrated** applies only the explicit per-plate adjustments above. It
shows attainable appearance and must not be used as evidence of equal
parameter semantics. The source stays identical between modes; no fitting or
seed search occurs during a run. When both native parameter sets are identical,
the second mode reuses the same native PDF/raster and records that reuse.

All values, shared geometry, caveats and crop rectangles are in
`manifest.json`; actual fixture code and numeric input arguments are also
hashed and retained. M6 reverses the sine sign because the two circle
samplers traverse in opposite directions. That is coordinate conversion,
not a visual adjustment.

## Rendering and measurement contract

1. MetaPost reads the hash-verified upstream library. `mptopdf` embeds any
   TeX fonts into its PDF. Typst compiles the matching native fixture to PDF
   with system fonts disabled and a fixed DejaVu path plus embedded fonts.
2. Both PDFs use **the same Ghostscript invocation**: `pnggray`, the selected
   ppi, 4-bit graphics/text antialiasing, fixed media and an explicitly sized
   pixel grid. There is no `FitPage`, automatic crop, registration or rescale.
   Width and height are rounded from `mm × ppi / 25.4`. For example,
   M2 at 600 ppi is 2598 × 1228 px. Unexpected raster dimensions fail.
3. Metrics use decoded 8-bit grayscale pixels (0 black, 255 white). Full-frame
   scores include whitespace. C1 and S101 also report explicit physical
   regions to avoid hiding local changes behind large blank areas. Region
   edges use the same physical-to-pixel rounding, with a top-left origin.
4. **RMSE** is `sqrt(mean((source − Typst)²)) / 255`. **Dark coverage** is the
   fraction of pixels strictly below 128. **Ink coverage** is
   `mean(255 − gray) / 255`, preserving antialiased gray contribution. Ratios
   use Typst/source dark coverage and are null when the source has no dark
   pixels. Difference images show absolute differences multiplied by 4 and
   clipped for display; metrics always use the unamplified originals.

Compare scores only across the same source, frame, ppi, crop, renderer and
threshold. A low pixel RMSE on a sparse image can reward missing ink, while
equal dark coverage does not establish matching shapes. Inspect all three
measures and the images together. Previously recorded values in COVERAGE.md
are historical measurements and need not match this explicitly specified run.

Provenance includes source revision/NAR hash/SHA-256, locked nixpkgs revision,
tool versions, platform, font path, hashes of all drawing/driver/pipeline
inputs, a retained input snapshot, decoded-pixel hashes, command arguments,
logs and durations. A fixed `SOURCE_DATE_EPOCH` and UTC timezone are used.
Pixel/metric repeatability is the contract; elapsed times and absolute paths
will naturally differ, and binary PDF equality is not required.

Exit **0** means the requested builds and measurements completed. Nonzero
source-vs-port error is expected and is not a failure threshold. Exit **1**
means a plate or render step failed; later selected plates still run, and
the report keeps the failures. Exit **2** means invalid CLI/environment or
upstream configuration. This command never updates `visual/*.png`.

## Validation and extending the inventory

```sh
python3 -m unittest discover -s comparisons -p 'test_*.py'
./check.sh
```

The fast harness tests cover known metric values, grayscale vs. thresholded
coverage, physical crops/row strides, raster dimensions, corrupted images,
upstream checksum rejection, source-only case selection and preserving
provenance/continuing after failures. They are included in `check.sh`;
the expensive upstream builds remain an explicit `compare.sh` command.

To add a pair, provide the same declared physical frame and inputs in both
drivers, add its native branch in `plates.typ`, and move/add its manifest
entry under `cases`. Document every unshared parameter and any calibrated
override. Keep library implementation changes in a separate commit and run
the existing visual regression suite before accepting them.
