# fiziko.typ

MetaPost-style programmatic drawing for [Typst](https://typst.app) — a port of
the ideas in [jemmybutton/fiziko](https://github.com/jemmybutton/fiziko), the
MetaPost library written to automate ~800 black-and-white illustrations for a
physics textbook. The visual reference is the pinned upstream source at
[`54a63db`](https://github.com/jemmybutton/fiziko/tree/54a63dba8e6700a5e70d3508838edebcbf0f45fe),
reproduced in [`main-original.pdf`](main-original.pdf).
See the [capability inventory](COVERAGE.md) and
[supplemental source gallery](original/coverage.pdf) for the other families.

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
The current source tree has no project license declaration yet; the
upstream [fiziko repository uses GPL-3.0](https://github.com/jemmybutton/fiziko/blob/master/LICENSE.md),
so the project license and attribution need an explicit decision before
publishing.

### Capability map

| fiziko / MetaPost | fiziko.typ capability |
|---|---|
| `offsetPath(p)(f)` | `offset-path(pts, f)` — curve at a distance `f(t)` along the source-oriented normal, with `t` as normalized arc length |
| `draw brush(p)(w)` | `stroke-ink(pts, w, offset: .., seed: 0)` — variable-width band with width and offset functions evaluated by normalized arc length; by default it follows fiziko's 0.2 pt pen and 1.2 pt dash period, replacing thinner sections with ink-conserving dashes; the seed controls deterministic dash variation. Typst keeps the requested perpendicular width, while MetaPost's offset-curve fit can overshoot it on variable-width paths. |
| `sphere.c(d)` | `sphere(d, light: .., rings: auto, samples: 128, seed: 0, shadow-regions: (), shadow-planes: (), shadow-polygons: ())` — concentric Lambert-shaded rings with residual-aware alternating widths, reproducible per-ring phase jitter, and a fine rim; supports local masks and projected occluders; ring sample count can be raised for unusually large output; see [sphere comparison](sphere.typ) |
| `sphereLat(d, lat)` | `sphere-latitude(d, latitude:, light: .., seed: 1, shadow-planes: ())` — latitude projection, `orderFade`, sphere light model, source-scale spacing, and projected planar shadows; defaults to 180 drawing samples for better compile time, with `samples:` adjustable for larger figures |
| `tube.l(p)(r)` / `tube.t` | `tube(pts, radius, hatch: "l"/"t", seed: 0, ...)` — `radius` is a number or `t => r` by normalized arc length; longitudinal lines follow recursive power-of-two lane-count sections, with widths responding to the centerline tangent, radius slope, and light; transverse sections advance along both sampled offset boundaries, transfer the endpoint using one-third residual correction, orient each section from the selected boundary, and apply source-style line-order fading; widths follow cross-section lighting and open ends are joined. Offset geometry, exact cubic parameter transfer, path-angle shading, and randomized dash placement remain approximate; see [tube shading](tube.typ) |
| `tube.s`, `sphere.s`, `thinBrush.stipples` | `tube(pts, radius, hatch: "s", dot-range: (0.9, 1.2), dot-density: 0.56)`, `sphere-stipple-rings(d, dot-range: (0.9, 1.2), density: 0.55, ...)`, `sphere-stipple(d, ...)`, `stroke-stipple-brush(pts, w, dot-range: (0.9, 1.2), density: 0.5, ...)`, `stroke-stipple(pts, w, ...)` — tube stipples use three offset dot tracks per longitudinal lane; open brush tracks restart by quantized local width, and closed brush tracks stay continuous; sphere rings use concentric tracks. Brush density 0.5 is calibrated against S101 and checked across 0.5×–2× samples; tube and sphere defaults remain calibrated to S101. Use the parameters to tune other scales and profiles. See the [S101 sample](stipple.typ) and [pinned source comparison](original/stipple-reference.pdf) |
| `solidSurface`, `solid`, `gradientShade` | `solid-surface(path, ...)`, `solid(poly, style: "opaque"/"glass")`, `gradient-shade(poly, ...)` — raised bands and reusable scanline clipping inside polygons |
| `flatSurface.hatches`, `.stipples` | `flat-surface(poly, normal, style: "hatch"/"stipples", ...)` — light-shaded clipped strokes or stipples with a two-axis ink envelope; see [surface comparison](original/surface-reference.pdf) |
| `woodBlock`, `woodenThing`, `woodenSurface` | `wood-block(...)`, `wooden-thing(poly, ...)`, `wooden-surface(path, ...)` — grained block, arbitrary polygon clipping, and grain clipped to an offset band; see [wood example](wood.typ) |
| `pulleyWheel`, `wheel`, `shapeCenterOfMass` | `pulley-wheel(d)`, `wheel(d, spokes:)`, `polygon-centroid(poly)`, `centroid-marker(poly)` — shaded pulley, spoked wheel and simple-polygon area centroid; see [mechanical comparison](original/mechanical-reference.pdf) |
| `shadowsEnabled`, `shadowCut` | `shadow-planes:` / `shadow-polygons:` with `sphere-shadow-plane(polygon, depth)` (source front-pole depth convention) or `sphere-shadow-polygon(vertices)` (sphere-center XYZ) — project source-style depth planes or simple planar 3D polygons onto visible sphere samples; curved/non-planar occluders and exact path splitting are unsupported |
| `refractionAngle`, `reflectionAngle`, `refractionPath` | `trace-refraction` / `refraction-path` — intersects a closed polygon, applies Snell's law, and reflects on total internal reflection |
| `pointOnGlobe`, `globe`, `drawLandMass` | `globe-project` / `globe` — orthographic graticule and caller-provided coast polylines, linearly interpolated and subdivided to 5° before horizon clipping; see [globe edge cases](globe.typ) |
| `isoLines`, `cLine` | Not implemented — general contour maps and contour-line rendering |
| `eye`, `knotFromStrands`, `initKnot`, `addStrandToKnot` | `eye` / `strand-knot` — configurable stylized eye with seeded lashes; crossing-aware open or self-crossing polylines; see [eye](eye.typ) and [strand crossing cases](knot.typ) |
| `label`/`btex` | `tag($..$, pos, anchor: ..)` — labels are ordinary Typst content (real math) |
| `whatever` equations / `lHopitalPulley` | `solve.typ`: `solve-linear` (Gauss–Jordan with pivoting), `line-intersect`, plus MetaPost's `++`/`+-+` as `pyth-add`/`pyth-sub`; `l-hopital-pulley(AB, l, m, at: ..)` draws the whole figure |
| `woodenThing(..)` / year rings | `wood(x, y, w, h, angle:, spacing:, eyes:)` — rings as level sets via `contour.typ` (marching squares + exact edge-ID chain stitching); each eye adds a log "twig function" so rings wrap the knot; arbitrary simple masks use `wooden-thing(poly, ...)` |
| `drawmidarrow` / `markAngle` | `vector(a, b, w:, head:)` (shaft + filled triangle head) and `mark-angle(a, o, b, r:, ticks:)` (short-sweep arc + radial ticks) |
| `spring` / `lens` / `weight` | `spring(a, b, coils:, rad:)` — sine projection of a helix; `lens(ap, sag, rim:, right-sag:, axis:, at:)` — one three-anchor formula supports symmetric or asymmetric convex, concave, and plano profiles; `weight(h, r:, at:)` and `weight-standing(h, r:, at:)` — hanging and standing tapered tubes |
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
typst compile optics.typ optics.pdf
typst compile globe.typ globe.pdf
typst compile knot.typ knot.pdf
typst compile mechanics.typ mechanics.pdf
typst compile telescope.typ telescope.pdf
typst compile eye.typ eye.pdf
typst compile tube.typ tube.pdf
typst compile sphere.typ sphere.pdf
```

The optional `original/` directory contains local upstream MetaPost sources and
comparison plates. It is intentionally not tracked by this repository, to avoid
vendoring a second copy of the original project. If present locally, rebuild its
comparison PDFs with `bash original/build.sh`.

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
- Typst does not emit PDF/X yet (typst/typst#6012) — post-process with
  Ghostscript for delivery.

## Prepress preflight

`./preflight.sh [file.pdf]` runs the print-readiness checks (Nix supplies
poppler/qpdf/ghostscript on the fly). These measurements are from the current
five-page `main.pdf` after Figure 11:

| check | tool | result |
|---|---|---|
| syntax / streams | `qpdf --check` | no errors |
| render | `gs -dPDFSTOPONERROR` | no errors, 5 pages |
| page | `pdfinfo` | A4 exact (595.28 × 841.89 pt), PDF 1.7, tagged, unencrypted, no JS |
| fonts | `pdffonts` | 5/5 embedded, subset + Unicode (NewCM roman/italic/bold, NewCM Math, DejaVu Sans Mono) |
| colour | qdf scan | 314 black-gray `scn` ops; 44 non-gray `scn` values and two `k` operators are from code highlighting; no `rg`, `RG`, or `K` operators |
| transparency | qdf scan | 0 × (`/SMask`, `/ca`, `/BlendMode`, `/Group`) |
| images / annotations | qdf scan | 0 / 0 — fully vector |
| stroked paths | qdf `w` ops | min **0.35 pt** (0.35 / 0.4 / 0.45 / 0.5 / 0.6); latitude hatches are fills, not `w` operators |
| latitude hatch widths | source-matched fill geometry | min **0.2 pt**, with below-pen widths represented by fitted dashes |
| OutputIntent | qdf scan | absent → not PDF/X (Typst typst#6012) |

Deliverables:

- `main.pdf` — master (screen and colour print).
- `page-{p}.png` — 140 ppi page previews, regenerated with `typst compile`.
- `main-gray.pdf` — single-K candidate from the earlier four-page specimen;
  regenerate it from the current master before delivery. Ghostscript
  `-sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray`;
  re-checked: all colour ops are valid DeviceGray in [0, 1], fonts stay
  embedded, renders clean. Caveat: GS rewrites coordinates in 0.1 pt units
  under a page-level scale, so raw `w` numbers in *its* qdf appear ×10 —
  verify widths against the scale matrix, not by grepping numbers alone.
- PDF/X-1a needs three things together: Ghostscript's `pdfx_def.ps`, a CMYK
  ICC (a FOGRA39L profile exists in the nix store via `colorprofiles`), and
  veraPDF to certify. They were not all available here; an incomplete attempt
  was produced and **deleted** — never deliver an uncertified file labelled
  PDF/X.

## Environment baseline

Last recorded during the 2026-09 baseline pass:

- Typst 0.15.1
- Nix 2.34.8
- qpdf, Poppler, and Ghostscript are supplied temporarily by `nix shell` in
  `preflight.sh`; their exact versions are not yet pinned.

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

`check.sh` covers existing numerical invariants and one rendered Typst page;
it is not a complete source-fidelity gate. Resolve licensing, pin build tools,
add CI/package metadata and close print/PDF/X checks before publishing.

## Release follow-up

- Pin or record Typst, qpdf, Poppler, and Ghostscript versions so preflight
  results can be reproduced.
- Decide which generated PDFs belong in the release and document the exact
  commands that regenerate them.
- Keep PDF/X marked as unverified until a conversion passes veraPDF.
