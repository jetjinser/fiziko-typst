# Upstream graphical capability inventory

Reference: the unmodified `fiziko.mp` at upstream revision
[`54a63db`](https://github.com/jemmybutton/fiziko/tree/54a63dba8e6700a5e70d3508838edebcbf0f45fe).
It is fetched and hash-verified through the Nix lock file.
`comparisons/reference/main.mp` supplies source figures **M1–M11**;
`comparisons/reference/supplemental.mp` supplies **S101–S108**. Inside the
project devshell, run `./compare.sh --source-only` to rebuild all 19 source
plates, or `./compare.sh` for paired core comparisons. See the
[comparison guide](comparisons/README.md).

The 19 historical source plates M1–M11 and S101–S108 now have Typst pairs;
C1 is an additional isolated concentric-sphere pair. New 600 ppi nominal
results and component crops are in `build/source-parity/index.html`, with the
ranked next steps in `comparisons/fidelity-plan.md`. Numerical scores below
are historical investigation results; use each generated report's recorded
renderer, ppi, crop, mode and threshold for its measurements.

**Approximate** means Typst can draw the subject, while its source algorithm
or visible details still differ. **Missing** means no corresponding drawing
capability is exposed. The source is a capability and visual reference, not a
requirement to copy MetaPost's recursion or match its internal call counts.

| Upstream family | Source plate | Typst capability | Status and principal difference |
| --- | --- | --- | --- |
| `offsetPath`, `brush`, `thinBrush` | M1–M2 | `offset-path`, `stroke-ink` | Approximate: open paths use a linear-time Hobby spline with unit tension and curl 1, matching MetaPost's automatic control points; closed paths use Catmull–Rom. Straight and constant-width curved strokes align closely. MetaPost's Tiller–Hanson offset construction can overshoot the sampled width profile (on a straight three-segment test, a 3 pt peak produced a 7.75 pt band); Typst instead keeps the requested perpendicular width. Thin-brush recursion and seeded dash placement also differ. On the matching 110 × 52 mm M1 plate, whole-frame RMSE is 0.05538 at 600 ppi and dark coverage is 0.6456% versus 0.6659% in MetaPost; offset-path sampling `per: 24` scores better than 48/96/192 (0.05554/0.05558/0.05560), so denser sampling is not useful for this curve. On M2, a joint amplitude/profile scan improves the Typst main sample from `8.5 pt · sin²` (RMSE 0.08258, dark coverage 3.201%) to `7.5 pt · sin` at `per: 96` (RMSE 0.03038, dark coverage 3.595% versus 3.598% in MetaPost). The `7.5 pt · sin` profile also beats tested amplitudes 7.0–9.5 pt and exponents 0.9–2.5; increasing sampling beyond 96 gives no benefit. Amplitude 7.6 pt lowers RMSE slightly further (0.03023) but overshoots coverage to 3.643%, so 7.5 pt is the better area/shape balance. A 16-seed scan at the calibrated profile gives a best RMSE of 0.030376 at seeds 0, 1, and 15; keep source seed 1 rather than overfit the dash phase. The source-literal 3 pt `sin²` profile remains in `brush.typ`; using it directly with Typst yields RMSE 0.1554 and 1.135% coverage, so the main sample calibrates the visible envelope while the library retains source width semantics. |
| `thinBrush.stipples` | S101 | `stroke-stipple-brush` | Approximate: open tracks use quantized, width-driven recursion with per-leaf pattern restart, paired seeded phases and per-leaf 0.9–1.2 dot-size variation; closed paths retain a continuous track distribution. The deterministic phase stream differs from MetaPost's global RNG. With PDFs rasterized by the same Ghostscript version, density 0.5 gives source-relative coverage of 88.7%/106.9%/94.5% at 0.5×/1×/2×; the isolated S101 crop is 0.2186% versus 0.2215% in the source. See `diagnostics/README.md`. |
| `sphere.c` | M5, M8 | `sphere` | Approximate: power-of-two ring count, residual-aware alternate-ring widths, seeded per-ring phase jitter, and a silhouette-clipped fine rim are implemented; lightness and dash placement differ. Independent phases keep results stable when path sampling changes; MetaPost instead interleaves ring phases with its global dash random stream. On the exact M5 composite, the 600 ppi sphere-region crop (including the tube overlap) has RMSE 0.12210 with actual `seed: 14`, versus 0.12462 with `seed: 1`; a 16-seed sweep selected this plate-specific value because the source draws its tube before the sphere. Thresholded crop coverage is 8.908% at seed 14 and 8.929% at seed 1, versus 8.998% in MetaPost, so seed 1 is marginally closer by area while seed 14 lowers pixel RMSE. A gamma scan from 0.6 to 1.4 confirms `gamma: 1.0` is best for this crop; 1.1 is next at RMSE 0.13164. The main M5 composition uses seed 14, while standalone `sphere.typ` keeps seed 1. An isolated 26 mm source-seeded sphere gave crop RMSE 0.13152/0.11616/0.11589/0.11973 at 64/128/256/512 samples, confirming 128 is near the accuracy plateau. The M8 specimen explicitly uses source seed 1; the small suspended sphere's cropped error changes only slightly versus seed 0. See `sphere.typ`. |
| `sphereLat` | M3 | `sphere-latitude` | Approximate: lighting and thin-mark distribution differ. At matching 110 × 56 mm geometry and 600 ppi, the two-sphere plate uses 360 samples and `seed: 15`, with 0.06729 whole-frame raster RMSE; thresholded dark coverage is 2.343% versus 2.349% in the source. The 180/360/720 sample sweep at seed 1 gives RMSE 0.06909/0.06848/0.06917 and coverage 2.340%/2.344%/2.344%; 360 remains the useful accuracy/runtime balance. A 0–15 seed sweep at 360 samples selects 15 (seed 1: 0.06848 RMSE, 2.34368% coverage; seed 15: 0.06729, 2.34348%). This is a plate-specific choice, not a new library default. Projected latitude geometry and density are visually close; most residual error is short-mark placement. |
| `sphere.s` | S101 | `sphere-stipple-rings` and `sphere-stipple` | Approximate: concentric lanes use Lambert shading, source-scale phase, per-track dot-size variation, independently keyed spacing jitter, and silhouette-clipped boundary dots. `density:` defaults to 0.55; in a same-renderer S101 scan it has lower crop and whole-plate RMSE than 0.58/0.60, though its local coverage is 11.810% versus 13.111% in the source. The separate 2D jittered field remains available. See `diagnostics/README.md`. |
| `tube.l` | M4–M6 | `tube(hatch: "l")` | Approximate: source-scale power-of-two spacing, recursive lane-count sections, per-section alternating residual widths, 0.2 pt source defaults, centerline-tangent and radius-slope-aware normals; offset-curve geometry, lightness sampling, and randomized dash placement differ; open end caps are joined. In matching 600 ppi comparisons, M4 (110 × 56 mm) has whole-frame RMSE 0.0694 and dark coverage 1.459% versus 1.506% in the source; its source-matched seed 1 is best in a 16-seed sweep. A matching-plate path-sampling scan at per 1/2/4/8/12/16/24/32 gives RMSE 0.07449/0.07025/0.06943/0.07038/0.07107/0.07045/0.07106/0.07083, confirming the current per 4. An isolated-outline probe improved from RMSE 0.02911/0.249% coverage to 0.01965/0.127% when halving the nominal pen width, close to the source's 0.129%; however, this alone worsened the full M4 plate to RMSE 0.07302 and coverage 1.336%. Combining it with `max-w: 0.34 pt` to restore total coverage worsened RMSE further to 0.07433, so the full-width outline and 0.30 pt shading default remain. M6 (110 × 62 mm) has RMSE 0.08743 and dark coverage 1.913% versus 1.957%; using seed 12 for both tubes slightly improves on seed 1 (RMSE 0.08787, coverage 1.910%) in a 16-seed sweep, so the main plate uses 12 while `tube.typ` keeps the source seed. With both tubes at seed 12, a ring path-sampling scan at per 1/2/4/8/16 gives RMSE 0.09062/0.08743/0.08771/0.08829/0.08816; the current per 2 is best among these. The overall shapes are close; residual differences are concentrated in short hatch marks and variable-radius offset geometry. See `tube.typ`. |
| `tube.t` | M7 | `tube(hatch: "t")` | Approximate: transverse strokes advance along both offset-boundary arc lengths with one-third residual remapping, source-side orientation, and `orderFade`. Cross-section widths now use five quarter-interval samples, matching MetaPost's four-piece `offsetPathSubdivide` before `offsetPathTemplate`; at matching 110 × 42 mm geometry and 600 ppi, 5/9/17 samples at per 192 and period 0.72 pt give RMSE 0.123561/0.124061/0.125857 and dark coverage 3.3243%/2.9758%/2.8908%, versus source 3.3284%. With five samples, a per sweep at period 0.90 pt gives RMSE 0.128648/0.123882/0.123106/0.122743/0.122636/0.122376/0.122895/0.123029/0.123124 at per 48/96/192/256/320/384/448/512/768; 384 reaches the measured plateau. At per 384, periods 0.72/0.90/1.00 pt give RMSE 0.122961/0.122376/0.122507 and dark coverage 3.3268%/3.3261%/3.3142%; the main samples use per 384 and period 0.90 pt. Rechecking seeds 0–15 with the final five-point cross-sections and these parameters confirms seed 1 as best (RMSE 0.122376); seed 14 is next at 0.122395. In an exact outline-only comparison using the M7 source construction (`offsetPathSubdivide`, `offsetPathTemplate`, and both `offsetPathGenerate` boundaries drawn with `thinpen`), coverage is 0.39790% for MetaPost and 0.39732% for Typst, with whole-frame RMSE 0.00528. The remaining full-plate difference is concentrated in short dash placement and cross-section lighting. |
| `tube.s` | S101 | `tube(hatch: "s")` | Approximate: source-scale lane and dot pitch, three offset dot tracks per lane, one-third ink per track, seeded 0.9–1.2 dot-size variation, independently keyed spacing jitter, and locally tangent-clipped dots at curved sides and open end caps. `dot-density:` defaults to 0.56; with matched Ghostscript rendering, its S101 tube crop has 5.2588% coverage versus 5.2583% in the source; tested 0.50/0.60 candidates have worse area balance. See `diagnostics/README.md` and `tube.typ`. |
| `tube.e` | S102 | `tube(hatch: none)` | Approximate: outline width and boundary interpolation differ; open ends are now joined. |
| Sphere cast-shadow regions | S102 | `sphere`, `sphere-stipple`, `sphere-latitude` `shadow-regions:`, `shadow-planes:`, `shadow-polygons:` | Approximate: local masks, source-compatible depth planes, and arbitrary-orientation simple planar 3D polygons project onto visible sphere samples. On upstream S102, the matching 26 mm sphere crop at 600 ppi scores RMSE 0.11295 using the source front-pole depth convention, down from 0.15876 with center-relative depth and geometric XY ray projection. `sphere-shadow-plane` follows source `shadowDepth`; 3D polygons retain center-relative XYZ coordinates and ray-plane intersection. Curved or non-planar occluders and exact path splitting remain unsupported. |
| `solidSurface`, `solid`, `gradientShade` | S103 | `solid-surface`, `solid`, `gradient-shade` | Approximate: scanline clipping is polygon-native; glass gaps and gradient widths differ from source. |
| `flatSurface.hatches`, `.stipples` | S104 | `flat-surface(style: "hatch"/"stipples")` | Approximate: Lambert shade and a two-axis line/edge ink envelope control deterministic clipped strokes or stipples. |
| `woodBlock`, `woodenThing`, `woodenSurface` | M9, S105 | `wood-block`, `wooden-thing`, `wooden-surface`, `wood` | Approximate: knot-warped field, source-rounded 1 mm extents, landscape axis swapping, 28 accepted-knot brush draws and the traced S105 stream offset are mapped. `contour-brush: "cell-range"` applies the source per-cell width law after undoing the field's 1/24 normalization; it improves S105 but regresses M9, so remains explicit. Brush recursion, exact traversal interpolation and random-call ordering remain approximate. |
| `isoLines`, `cLine` | M9 wood; general fields | `contour-lines`, `iso-lines` | Approximate: arbitrary scalar fields can produce stitched isoline polylines at explicit levels or be drawn directly. Cell-center masks, callbacks and a `"source"` local-range width law are exposed; source cLine's traversal-dependent interpolation, brush recursion and masked-cell continuation remain approximate. See `isolines.typ`. |
| `spring` | M10 | `spring` | Approximate: coil shape and end joins differ. |
| `weight.h`, `weight.s` | M10, S106 | `weight`, `weight-standing` | Approximate: source-proportional body radii, 2 mm hanging-body offset and a 2*shadingDensity auricle capsule are mapped; auricle interior shading and tube hatch profiles still use simpler continuous tube construction. |
| `lens` profiles | M10, S108 | `lens(right-sag:)` | Approximate: asymmetric, concave and plano profiles are supported; curved faces use sampled spline arcs rather than exact circles. |
| `pulley`, `pulleyWheel`, `wheel` | M8, S107 | `pulley`, `pulley-wheel`, `wheel` | Approximate: native rim, groove and spoke construction replaces source shading and masks. |
| `shapeCenterOfMass` | S107 | `polygon-centroid`, `centroid-marker` | Approximate: standard area centroid for simple polygon vertices. |
| `drawmidarrow`, `markAngle` | S108 | `vector`, `mark-angle` | Approximate: arrow and label placement differ. |
| `refractionPath`, reflection | M11 | `refraction-path` | Approximate: sampled polygon boundaries. |
| `globe`, landmass projection | M11 | `globe` | Approximate: caller-supplied coasts default to 5° linear densification; `coast-step: 0` connects projected input vertices directly, matching the source M11 polygonal paths. Horizon clipping and source-style projected-radius coastline widths are implemented. Latitude-layer widths and coast RNG phase remain approximate; built-in coast data is not part of the public API. The M11 comparison fixture supplies the eight coast paths from the pinned upstream source. |
| `eye` | M11 | `eye` | Approximate: configurable anatomy and deterministic lashes; shapes differ from the source. Aspect, gaze and rotation edge cases are shown in `eye.typ`. |
| `knotFromStrands`, styles and layers | M11 | `strand-knot` | Approximate: open and self-crossing polylines support alternating crossings or explicit per-crossing layers, including paths with duplicate vertices. Tube style maps source strand values directly to Typst radii; its hidden interval expands by the crossing angle. Curve-time crossing detection, source tube-mask edges, and shadow handling still differ. |

For M3, a fresh 600 ppi full-frame `max-w` scan at the current `main.typ`
settings (`samples: 360`, `seed: 15`, shared RNG cursor) tested 0.26/0.28/
0.29/0.30/0.31/0.32/0.34 pt. RMSE was 0.075968/0.073653/0.072419/
0.069539/0.071870/0.074122/0.077168; dark coverage was 1.9689/2.1624/
2.2556/2.3441/2.4347/2.5329/2.7186%, against source coverage 2.3491%.
The current 0.30 pt width is best on both measures; the prior width formula
needs no adjustment.

An M6 normal-shading probe tested doubling the radius-profile slope to match
the full-diameter `tubeWidth` template. This was incorrect: upstream computes
the normal angle from `tubeWidth yscaled 1/2`, which restores the radius
profile. On a same-size M6 render at 300 ppi, the doubled-slope candidate
scored RMSE 0.08843 against the upstream page, versus 0.07624 for the current
radius-slope implementation; thresholded dark coverage also rose from 1.893%
to 2.370% (source: 2.010%). The candidate was discarded.

For M4, `max-w: 0.308 pt` improves the source-matched 110 × 56 mm plate at
600 ppi: RMSE falls from 0.069426 to 0.069273 and dark coverage moves from
1.45864% to 1.50485% (source: 1.50558%). A 0.31 pt trial overfilled the
plate and raised RMSE to 0.071743. The main M4 figure and `tube.typ` specimen
use 0.308 pt; the library-wide tube default stays at 0.30 pt.

The M4 width adjustment does not transfer to the variable-radius M6 tubes.
At the matching 110 × 62 mm frame, 600 ppi, and seed 12, scanning a shared
`max-w` from 0.300 to 0.308 pt gives RMSE 0.087463/0.087869/0.087998/
0.087873/0.088010/0.088028 and dark coverage 1.9132/1.9234/1.9341/
1.9479/1.9528/1.9608%, respectively. The source measures 1.9573% coverage;
0.307 pt is closest by area, but has higher image error than the default.
Keep M6 at the library default because the denser ink shifts the variable-
radius hatches away from the source pattern.

A follow-up source lane trace found that the cross-section lane order was
mirrored in Typst. Reversing the lane coordinate while keeping the current
lightness formula unchanged aligns widths by lane index: across the M4 tube's
63 inner lanes, the mean sum of min/max width errors is 0.00093 mm. At 600 ppi
the corrected M4 RMSE is 0.068799 (coverage 1.508%, source 1.506%), down from
0.069273. The same change improves the variable-radius M6 plate to RMSE
0.08584 (coverage 1.964%, source 1.958%), down from 0.08743. Source and Typst
per-lane recursion counts still differ; dash placement and phase remain open.
The comparison traces are in `diagnostics/README.md`.

A same-size 300 ppi M7 render confirms the current transverse-hatch coverage is
already close (3.4077% versus 3.4125% in the source). `orderFade`, the radius
slope correction, and the five-knot cross-section width interpolation match
the corresponding source formulas; the remaining visible residual is mainly
mark placement and offset-boundary interpolation, not overall ink density.
An equal-arc-length pairing candidate changed 600 ppi RMSE only from 0.122376
to 0.122351 while moving dark coverage farther from the source (3.32547% vs.
3.32838%, compared with 3.32613% for the current mapping). Its additional
per-section boundary searches are not justified by that marginal score change,
so the shared-parameter mapping remains.

A source-code review rechecked the one-third residual endpoint correction.
Although the residual is measured on the opposite boundary, MetaPost maps the
corrected parameter back onto the boundary used for the initial candidate.
Moving the corrected distance onto the opposite boundary was a mistaken
interpretation: an M7 test raised 600 ppi RMSE from 0.122376 to 0.189712 and
lowered dark coverage from 3.32613% to 3.21923%. That candidate was reverted;
the current endpoint mapping follows the source.

Concentric and 2D-stipple sphere lighting now clamp the normalized Lambert
dot product to both ends of `[0, 1]`, matching `normalVectorToLightness`; this
prevents round-off above 1 from creating negative widths or invalid dot
probabilities.

An M5 phase-stream candidate keyed each ring rotation to the preceding ring's
Typst dash-consumption cursor, approximating the source's interleaved random
calls. On the 300 ppi sphere-and-tube crop its RMSE worsened from 0.09947 to
0.10458, and coverage moved from 7.656% to 7.632% (source: 7.871%). Keep the
current independent keyed phases; they give the better seeded plate match and
remain stable when ring sampling changes.

A local `max-w: 0.303 pt` M5 trial brought crop coverage from 7.656% to 7.717%
(source: 7.871%) but worsened 300 ppi RMSE from 0.09947 to 0.10557. The
nominal 0.30 pt width remains the better shape match; increasing ink alone
does not correct the ring-mark positions.

This accounts for the source's public graphical families. Internal helpers
(`offsetPathTemplate`, `tubeGenerate`, `isoLines`, `cLine`, horizon search,
list utilities and 3-D rotation) are in scope when their behavior is needed
to reproduce a family's output; API names need not match.

The stippled brush, sphere, and tube are compared on S101 with the pinned
MetaPost figure as the target. For brush calibration, both the MetaPost output
and Typst PDF are rasterized through Ghostscript at 600 ppi; earlier scans
mixed Typst's PNG renderer with Ghostscript and are superseded. On the isolated
S101 brush crop (1087 × 662 px), density 0.5 gives 0.2186% dark coverage
versus 0.2215% in the source, with RMSE 0.05740. The same density checked at
0.5×/1×/2× yields coverage of 0.3142%/0.2351%/0.1332%, compared with
0.3540%/0.2200%/0.1410% in the source. It is a practical shared balance;
lower densities reduce pixel RMSE but leave more of the source ink unmatched.
The full S101 plate at these settings has RMSE 0.18317 and dark coverage
2.6563% versus 2.8237% in MetaPost; most remaining full-frame error comes
from the sphere and tube as well as dot placement.

The brush trace records 60 drawable source leaves and 180 local pattern calls.
Sphere rings produce 1,930 leaves, 5,790 calls, and 6,942 reconstructed dots;
the tube produces 687 leaves, 2,061 calls, and 4,067 dots. The three source
families have similar dot-size distributions. Typst's recursive brush model
approximates the source's width-driven cuts, but the keyed phase stream does
not reproduce MetaPost's global random sequence. Geometry remains close:
maximum brush leaf endpoint error is 0.00009 mm and maximum arc-length error
is 0.000014 mm. The instrumented traces and rerender commands are in
`diagnostics/README.md`.

The manual also has complex *composite examples*, including a telescope.
Those need separate reference plates after their component families work;
they are not claimed complete by this inventory. M8, M5 and M10 already
cover smaller pulley and physics compositions.

## Progress on roadmap items 2–5

2. **Shadows and wood:** `shadow.typ` compares manual masks, depth planes, and
   tilted 3D polygons; the 3D polygon works on concentric, latitudinal, and
   stippled spheres. `wood.typ` exercises convex and concave masks. Curved or
   non-planar shadow casters remain unsupported by design.
3. **Globe, eye, knots, and optics:** `globe.typ`, `eye.typ`, `knot.typ`, and
   `optics.typ` cover horizon crossings, gaze and aspect extremes, duplicate
   strand vertices and self-crossings, refraction, and total internal
   reflection.
4. **Mechanical details:** `mechanics.typ` shows spring, both weight forms,
   asymmetric and concave lenses, pulley, and wheel in one focused plate.
5. **Composite and project audit:** `telescope.typ` combines existing drawing
   primitives into a telescope. Documentation and generated-file ignores are
   updated; the optional upstream `original/` directory remains untracked.
   The project now declares `GPL-3.0-or-later` and preserves upstream
   attribution. Typst Universe publication remains deferred while the
   maintainer reviews the package and decides what author metadata to publish.

After each drawing-code change, compile the focused specimen and `main.typ`.
Keep the pinned, seeded source plates fixed as a common comparison target.

The Stage 4 source-plate pass now measures brush, sphere, tube stipple and
transverse dash behavior across multiple scales or seeds. The remaining
differences are documented as source-pattern phase and density tradeoffs;
matching MetaPost's internal recursion and call counts is still not a
completion requirement. See `diagnostics/README.md` for the bounded audit and
reproduction commands.
