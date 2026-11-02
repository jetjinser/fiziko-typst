# fiziko.typ

MetaPost-style programmatic drawing for [Typst](https://typst.app) — a port of
the ideas in [jemmybutton/fiziko](https://github.com/jemmybutton/fiziko), the
MetaPost library written to automate ~800 black-and-white illustrations for a
physics textbook. The visual reference is the pinned upstream source at
[`54a63db`](https://github.com/jemmybutton/fiziko/tree/54a63dba8e6700a5e70d3508838edebcbf0f45fe),
locked together with its renderers by Nix. See the
[reproducible upstream comparisons](comparisons/README.md) and
[capability inventory](COVERAGE.md).

## Project status

The goal is capability coverage of the useful fiziko drawing system, with a
Typst-native API and practical compile performance. The source is a visual
reference, but exact API, path subdivision, and dash-call compatibility are
not goals. A feature is complete when its output is useful and predictable,
its performance is acceptable, and its behavior, limits, and examples are
documented.

Current baseline: core paths, strokes, concentric and latitudinal spheres,
tubes, wood grain, geometry helpers, and several physics primitives are
implemented. The latitudinal sphere was compared against the upstream Figure
12 render; the current five-page specimen passes the local qpdf/Ghostscript
preflight. Thin brush marks
accept a deterministic `seed`; orthographic globe projection, layered strand
crossings, an anatomical eye, and polygonal refraction are now implemented.
Wood-grain eyes are distinct from the upstream `eye` illustration. Globe
coastlines are caller-supplied polylines; the upstream data bundle is not
embedded. Knot crossings use sampled polylines, alternate by pair by default,
and can use a fixed strand ordering; polygonal boundaries approximate smooth
optical surfaces.
This package is licensed under GNU GPL version 3 or later. It ports the
upstream Fiziko library by Sergey Slyusarev, Copyright 2023; retain the
upstream attribution and license notice in [LICENSE](LICENSE). See
[release readiness](RELEASING.md) for package publication status.

### Capability map

| fiziko / MetaPost | fiziko.typ capability |
|---|---|
| `offsetPath(p)(f)` | `offset-path(pts, f)` — curve at a distance `f(t)` along the source-oriented normal, with `t` as normalized arc length |
| `draw brush(p)(w)` | `stroke-ink(pts, w, offset: .., seed: 0)` — variable-width band with width and offset functions evaluated by normalized arc length; by default it follows fiziko's 0.2 pt pen and 1.2 pt dash period, replacing thinner sections with ink-conserving dashes; the seed controls deterministic dash variation. Typst keeps the requested perpendicular width, while MetaPost's offset-curve fit can overshoot it on variable-width paths. |
| `sphere.c(d)` | `sphere(d, light: .., rings: auto, samples: 128, seed: 0, shadow-regions: (), shadow-planes: (), shadow-polygons: ())` — concentric Lambert-shaded rings with residual-aware alternating widths, reproducible per-ring phase jitter, and a fine rim; supports local masks and projected occluders; ring sample count can be raised for unusually large output; see [sphere comparison](sphere.typ) |
| `sphereLat(d, lat)` | `sphere-latitude(d, latitude:, light: .., seed: 1, shadow-planes: ())` — latitude projection, `orderFade`, sphere light model, source-scale spacing, and projected planar shadows; defaults to 180 drawing samples for better compile time, with `samples:` adjustable for larger figures |
| `tube.l(p)(r)` / `tube.t` | `tube(pts, radius, hatch: "l"/"t", seed: 0, ...)` — `radius` is a number or `t => r` by normalized arc length; longitudinal lines follow recursive power-of-two lane-count sections, with widths responding to the centerline tangent, radius slope, and light; transverse sections advance along both sampled offset boundaries, transfer the endpoint using one-third residual correction, orient each section from the selected boundary, and apply source-style line-order fading; widths follow cross-section lighting and open ends are joined. `rng: "metapost"` replays the scaled random stream for longitudinal hatch dashes (M4 fixture). Offset geometry, exact cubic parameter transfer, path-angle shading, and randomized dash placement in transverse hatches remain approximate; see [tube shading](tube.typ) |
| `tube.s`, `sphere.s`, `thinBrush.stipples` | `tube(pts, radius, hatch: "s", dot-range: (0.9, 1.2), dot-density: 0.56)`, `sphere-stipple-rings(d, dot-range: (0.9, 1.2), density: 0.55, ...)`, `sphere-stipple(d, ...)`, `stroke-stipple-brush(pts, w, dot-range: (0.9, 1.2), density: 0.5, ...)`, `stroke-stipple(pts, w, ...)` — tube stipples use three offset dot tracks per longitudinal lane; open brush tracks restart by quantized local width, and closed brush tracks stay continuous; sphere rings use concentric tracks. Brush density 0.5 is calibrated against S101 and checked across 0.5×–2× samples; tube and sphere defaults remain calibrated to S101. Use the parameters to tune other scales and profiles. See the [S101 sample](stipple.typ) and [reproducible S101 comparison](comparisons/README.md) |
| `solidSurface`, `solid`, `gradientShade` | `solid-surface(path, ...)`, `solid(poly, style: "opaque"/"glass")`, `gradient-shade(poly, ...)` — raised bands and reusable scanline clipping inside polygons |
| `flatSurface.hatches`, `.stipples` | `flat-surface(poly, normal, style: "hatch"/"stipples", ...)` — light-shaded clipped strokes or stipples with a two-axis ink envelope; see [source surface plates](comparisons/README.md) |
| `woodBlock`, `woodenThing`, `woodenSurface` | `wood-block(...)`, `wooden-thing(poly, ...)`, `wooden-surface(path, ...)` — grained block, arbitrary polygon clipping, and grain clipped to an offset band; `source-field` mode supports `seed:` and `rng-offset:`, with `contour-brush: "cell-range"` selecting the source-inspired per-cell brush-width law; see [wood example](wood.typ) |
| `pulleyWheel`, `wheel`, `shapeCenterOfMass` | `pulley-wheel(d)`, `wheel(d, spokes:)`, `polygon-centroid(poly)`, `centroid-marker(poly)` — shaded pulley, spoked wheel and simple-polygon area centroid; see [source mechanical plates](comparisons/README.md) |
| `shadowsEnabled`, `shadowCut` | `shadow-planes:` / `shadow-polygons:` with `sphere-shadow-plane(polygon, depth)` (source front-pole depth convention) or `sphere-shadow-polygon(vertices)` (sphere-center XYZ) — project source-style depth planes or simple planar 3D polygons onto visible sphere samples; curved/non-planar occluders and exact path splitting are unsupported |
| `refractionAngle`, `reflectionAngle`, `refractionPath` | `trace-refraction` / `refraction-path` — intersects a closed polygon, applies Snell's law, and reflects on total internal reflection |
| `pointOnGlobe`, `globe`, `drawLandMass` | `globe-project` / `globe` — orthographic graticule and caller-provided coast polylines; `coast-step:` controls interpolation before horizon clipping (default 5°, or `0` to project source vertices directly); `light:` sets the illumination used for latitude shading and source-style coast widths; see [globe edge cases](globe.typ) |
| `isoLines`, `cLine` | `contour-lines(field, x, y, w, h, levels, nx:, ny:, mask:)` returns connected polylines; `iso-lines(.., stroke:)` draws uniform strokes, while `width:` accepts a constant, callback, or cLine-inspired `"source"` width — fields are sampled on a regular grid and stitched by shared grid-edge identities; see [isolines](isolines.typ) |
| `eye`, `knotFromStrands`, `initKnot`, `addStrandToKnot` | `eye` / `strand-knot` — configurable stylized eye with seeded lashes; crossing-aware open or self-crossing polylines; tube style supports physical crossing gaps or local overpass silhouette masking; see [eye](eye.typ) and [strand crossing cases](knot.typ) |
| `label`/`btex` | `tag($..$, pos, anchor: ..)` — labels are ordinary Typst content (real math) |
| `whatever` equations / `lHopitalPulley` | `solve.typ`: `solve-linear` (Gauss–Jordan with pivoting), `line-intersect`, plus MetaPost's `++`/`+-+` as `pyth-add`/`pyth-sub`; `l-hopital-pulley(AB, l, m, at: .., length-labels: false)` draws the source-style figure; optional `length-labels: true` adds `l`/`m` labels |
| `woodenThing(..)` / year rings | `wood(x, y, w, h, angle:, spacing:, eyes:)` — rings as level sets via `contour.typ` (marching squares + exact edge-ID chain stitching); each eye adds a log "twig function" so rings wrap the knot; arbitrary simple masks use `wooden-thing(poly, ...)` |
| `drawmidarrow` / `markAngle` | `vector(a, b, w:, head:)` (shaft + filled triangle head) and `mark-angle(a, o, b, r:, ticks:)` (short-sweep arc + radial ticks) |
| `spring` / `lens` / `weight` | `spring(a, b, coils:, rad:)` — sine projection of a helix; `lens(ap, sag, rim:, right-sag:, axis:, at:)` — one three-anchor formula supports symmetric or asymmetric convex, concave, and plano profiles; `weight(h, r:, at:)` hangs downward with a source-sized auricle outline, while `weight-standing(h, r:, at:)` rises upward from its base |
| MetaPost figures | `canvas(w, h, ..children)` — compose elements with `+` |

Coordinates are plain millimetre floats (y down); the whole figure is a pure
function of its numbers and explicit seeds. Seeds default to `0`, so builds
remain repeatable unless a caller opts into another pattern.
Open paths use a linear-time, unit-tension Hobby spline with unit endpoint
curl, matching MetaPost's automatic `..` controls. Closed paths retain periodic
Catmull–Rom interpolation; `resample(..., spline: "catmull")` selects it for an
open path as well.

Pass an integer `seed:` to `stroke-ink`, `stroke-stipple-brush`,
`stroke-stipple`, `sphere`, `sphere-stipple`, `sphere-stipple-rings`,
`sphere-latitude`, `tube`, `eye`, or `strand-knot` to vary thin marks and lash
details. The same geometry and seed repeat the same dashes and dot placement;
another seed changes them without global random state.

## Usage

```typst
#import "fiziko.typ": *

#canvas(110, 52,
  stroke-path(((6, 36), (38, 16), (72, 34), (104, 14)),
              stroke: 0.6pt + black, per: 24)
  + stroke-ink(((6, 36), (38, 16), (72, 34), (104, 14)),
               t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
               closed: false, per: 24, seed: 42)
  + tag($m$, (50, 30)))
```

Build the specimen document (5-page A4):

```sh
typst compile main.typ main.pdf
typst compile main.typ 'page-{p}.png' --ppi 140
typst compile brush.typ brush.pdf
typst compile stipple.typ stipple.pdf
typst compile shadow.typ shadow.pdf
typst compile wood.typ wood.pdf
typst compile isolines.typ isolines.pdf
typst compile optics.typ optics.pdf
typst compile globe.typ globe.pdf
typst compile knot.typ knot.pdf
typst compile mechanics.typ mechanics.pdf
typst compile telescope.typ telescope.pdf
typst compile eye.typ eye.pdf
typst compile tube.typ tube.pdf
typst compile sphere.typ sphere.pdf
```

Build the source comparisons from a fresh checkout:

```sh
nix develop path:./nix
./compare.sh                        # core pairs, nominal and calibrated modes
./compare.sh --source-only          # all 19 historical source plates
```

Reports, PDFs, images, explicit parameters and provenance are generated under
`build/comparisons/`. Both sides use the same Ghostscript rasterizer. The
[comparison guide](comparisons/README.md) explains the modes, metrics and
individual plate selection. The optional ignored `original/` directory and
`main-original.typ` page wrapper are legacy local artifacts; the current
workflow does not depend on them.

## Regression checks

Generated PDFs and page previews are local build outputs. Older root-level
outputs have been archived under ignored `build/legacy/`; rebuild the desired
document using the commands above. Keep diagnostic sources in `diagnostics/`
and write new diagnostic output to `/tmp` or `build/`. The PNG under `visual/`
is a tracked regression fixture, not a disposable preview.

The stale Figure 11 snapshot identified during cleanup was reviewed and
updated: the differences come from document reflow, coast subdivision and
the revised seeded lash pattern. See the [review and comparison images](visual/reviews/2026-11-02-page-5/README.md).

Geometry is verified numerically (no eyeballing needed):

```sh
typst eval 'query(<verify>).map(it => it.value)' --in verify.typ
```

and fails if a hard geometric invariant is violated. It covers arc step length
(must be uniform), circle
radii, offset-band radii (± `offset` ± `w/2`), the brush width law, the tube
ink budget, the linear solver's residuals, the L'Hôpital pulley's rope-length
and equilibrium constraints and wheel tangency (all ~1e-16 for two parameter
sets), and the wood contour's field residual (points sit on an iso-level
within the marching-squares interpolation error) and chain continuity (no
jumps beyond one grid-cell diagonal). The same file has hard `assert`
conditions, including globe centre/horizon visibility, strand-gap width,
Snell's tangential invariant, and total internal reflection direction.

Enter `nix develop path:./nix`, then run the numerical checks, rebuild the
specimen at `build/check/main.pdf`, and compare the visual references:

```sh
./check.sh
```

The visual gate checks ten independent core plates at 200 ppi and Figure 11's
full A4 page at 130 ppi using Typst 0.15.1 and controlled fonts. It compares
decoded pixels and retains actual, difference and comparison images under
`build/visual/`. See [visual regression coverage and review instructions](visual/README.md)
for running individual cases and explicitly updating reviewed references.

## Gotchas learned the hard way

- `calc.sin`/`calc.cos` take **angles**: a bare number is *radians*, not
  degrees. Multiply degrees by `1deg` (see `_cos`/`_sin` in the library).
- `calc.atan2(a, b)` takes **(x, y)** — first the x component, second y
  (verified on four quadrants; the opposite of the usual `atan2(y, x)`
  mnemonic), and `angle` is a *type*, not a constructor.
- Top-level `let`s have no forward references: a function may only call
  names defined *above* it, so the pulley section lives at the end of
  `fiziko.typ`.
- `place(alignment, dx:, dy:, child)` positions the child relative to the
  *aligned point of the parent*, not the parent's origin. Anchoring a label at
  an arbitrary point therefore needs a zero-sized box wrapper (see `tag`).
- `box(..)` accepts a single body; join multiple children with `+`.
- Calling a function stored in a dictionary needs parens: `(L.rfun)(t)`, not
  `L.rfun(t)` (field access can clash with builtin methods).
- Everything a primitive returns into a `canvas` must be `place`-wrapped: a
  raw `curve` joins the box's *flow* and cumulatively shifts every following
  element — this produced a phantom arrowhead that seemed to survive our fix
  (it hadn't: the image pipeline was serving pre-fix bytes).

## Print notes (from the specimen)

- `stroke-ink` and tube outlines use fiziko's 0.2 pt pen by default. Explicit
  `stroke-path` widths remain caller-controlled. The source-matched latitude sphere uses fiziko's 0.2 pt pen,
  0.3 pt maximum shading width, and 0.9 pt line spacing; its hatches are
  filled vector geometry and remain single-K.
- Typst embeds font subsets; labels are New Computer Modern.
- Typst does not natively emit PDF/X ([upstream feature request](https://github.com/typst/typst/issues/6012)). A Ghostscript
  conversion also needs a print profile selected for the intended workflow and
  a PDF/X-capable conformance check before it can be labelled PDF/X.

## Prepress preflight

`nix develop path:./nix --command ./preflight.sh [file.pdf]` runs structural
and render checks using the versions pinned by `flake.lock`. These
measurements are from the current five-page `build/check/main.pdf`:

| check | tool | result |
|---|---|---|
| syntax / streams | `qpdf --check` | no errors |
| render | `gs -dPDFSTOPONERROR` | no errors, 5 pages |
| page | `pdfinfo` | A4 exact (595.28 × 841.89 pt), PDF 1.7, tagged, unencrypted, no JS |
| fonts | `pdffonts` | 5/5 embedded, subset + Unicode (NewCM roman/italic/bold, NewCM Math, DejaVu Sans Mono) |
| colour | qdf scan | `scn` includes black/gray drawing and colored code highlighting, plus two `k` operators; no `rg`, `RG`, or `K` operators |
| transparency | qdf scan | 0 × (`/SMask`, `/ca`, `/CA`, `/BlendMode`, `/Group`) |
| images / annotations | qdf scan | 0 / 0 — fully vector |
| stroked paths | qdf `w` ops | min **0.199 pt**; 0.2 pt source strokes are intentional; minimums required for print depend on the recipient |
| latitude hatch widths | source-matched fill geometry | min **0.2 pt**, with below-pen widths represented by fitted dashes |
| OutputIntent | qdf scan | absent; the document is not certified as PDF/X |

Generated files and release scope:

- `build/check/main.pdf` is the generated five-page specimen used for review
  and CI. It is not tracked or included in the source package.
- The source release is the Typst package plus its README and license. Example
  PDFs, page PNGs, comparison reports, and diagnostic renders stay as generated
  review artifacts under `build/` and are not release files.
- No grayscale or PDF/X variant is currently part of the release. The
  grayscale candidate referenced in older notes was made from an earlier
  specimen and is obsolete.
- veraPDF validates PDF/A and PDF/UA profiles; it does not validate PDF/X. The
  locked nixpkgs has no FOGRA print-profile package selected for this project,
  and no PDF/X validator is configured. PDF/X therefore remains unverified;
  do not label a Ghostscript output as conforming based only on an OutputIntent
  or a successful render.

## Environment baseline

The comparison environment is pinned in `nix/flake.lock`, including upstream
fiziko. The 2026-11 comparison pass uses:

- Typst 0.15.1
- MetaPost 2.11 / pdfTeX 1.40.27 (TeX Live 2025)
- Ghostscript 10.07.1
- ImageMagick 7.1.2-31 and Python 3.14.7
- qpdf 12.3.2, Poppler 26.06.0 and Ghostscript 10.07.1 for print preflight
- actionlint 1.7.12 and ShellCheck 0.11.0 for repository scripts

Every source comparison records its actual tool versions and source hashes.
Print preflight now uses the same locked devshell and records the versions of
qpdf, Poppler, and Ghostscript in its output.

## Roadmap

The [capability inventory](COVERAGE.md) tracks coverage and remaining visual
work. The core strokes, sphere/tube shading, stipples, surface fills,
polygon-clipped wood and main mechanical variants are implemented. Sphere
shadows accept XY depth planes and arbitrary-orientation planar 3D polygons.
The seeded source galleries remain visual references; MetaPost recursion and
dash-call counts are diagnostic data rather than completion gates. A license
and attribution decision is still needed before publication.

At Typst 0.15.1 in the local environment, reducing the latitude sphere's
default drawing resolution from 360 to 180 samples cut the two-sphere
comparison build from 40.5 to 20.9 seconds and the full five-page specimen
from 64.9 to 44.6 seconds. The width-template knots remain explicit, and
`samples:` can be raised for unusually large output. These timings depend on
the machine and document; they are measurements, not fixed targets.

`check.sh` runs numeric and visual regressions, comparison-tool unit tests,
shell/workflow lint, a local package import smoke build, the five-page compile,
and the structural PDF preflight. Source fidelity remains a descriptive
comparison rather than a pass/fail threshold.

## Release readiness

The pinned toolchain, CI gate, local Typst package manifest, package smoke
build, generated-file policy, and reproducible PDF preflight are in place.
Publication is still gated on maintainer confirmation of the project license,
author list, and attribution text. PDF/X is deliberately outside the release
scope until a target print profile and a validator that supports PDF/X are
chosen. See [RELEASING.md](RELEASING.md) for the remaining decisions.
