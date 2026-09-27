# Upstream graphical capability inventory

Reference (available locally in the optional, untracked `original/` directory):
the unmodified `original/fiziko.mp` at upstream revision
[`54a63db`](https://github.com/jemmybutton/fiziko/tree/54a63dba8e6700a5e70d3508838edebcbf0f45fe).
`original/main-original.mp` supplies source figures **M1–M11**;
`original/coverage.mp` supplies **S101–S108**. Run `bash original/build.sh`
to rebuild the local [main gallery](main-original.pdf) and
[supplemental gallery](original/coverage.pdf).

**Approximate** means Typst can draw the subject, while its source algorithm
or visible details still differ. **Missing** means no corresponding drawing
capability is exposed. The source is a capability and visual reference, not a
requirement to copy MetaPost's recursion or match its internal call counts.

| Upstream family | Source plate | Typst capability | Status and principal difference |
| --- | --- | --- | --- |
| `offsetPath`, `brush`, `thinBrush` | M1–M2 | `offset-path`, `stroke-ink` | Approximate: interpolation and thin-brush recursion differ. |
| `thinBrush.stipples` | S101 | `stroke-stipple` | Approximate: arc-length dot placement and independent spacing controls replace source random brush lanes. |
| `sphere.c` | M5, M8 | `sphere` | Approximate: ring lighting and dash placement need comparison. |
| `sphereLat` | M3 | `sphere-latitude` | Approximate: lighting and thin-mark distribution differ; Typst uses fewer drawing samples for speed. |
| `sphere.s` | S101 | `sphere-stipple` | Approximate: jittered 2D dot field with Lambert density; source uses a different placement pattern. |
| `tube.l` | M4–M6 | `tube(hatch: "l")` | Approximate: adaptive line placement, light and ink distribution differ; open end caps are now joined. |
| `tube.t` | M7 | `tube(hatch: "t")` | Approximate: stroke spacing and taper rules differ. |
| `tube.s` | S101 | `tube(hatch: "s")` | Approximate: dotted longitudinal placement and surface density differ; open end caps are now joined. |
| `tube.e` | S102 | `tube(hatch: none)` | Approximate: outline width and boundary interpolation differ; open ends are now joined. |
| Sphere cast-shadow regions | S102 | `sphere`, `sphere-stipple`, `sphere-latitude` `shadow-regions:`, `shadow-planes:`, `shadow-polygons:` | Approximate: local masks, depth planes, and arbitrary-orientation simple planar 3D polygons project onto visible sphere samples. Curved or non-planar occluders and exact path splitting remain unsupported. |
| `solidSurface`, `solid`, `gradientShade` | S103 | `solid-surface`, `solid`, `gradient-shade` | Approximate: scanline clipping is polygon-native; glass gaps and gradient widths differ from source. |
| `flatSurface.hatches`, `.stipples` | S104 | `flat-surface(style: "hatch"/"stipples")` | Approximate: Lambert shade and a two-axis line/edge ink envelope control deterministic clipped strokes or stipples. |
| `woodBlock`, `woodenThing`, `woodenSurface` | M9, S105 | `wood-block`, `wooden-thing`, `wooden-surface`, `wood` | Approximate: the same contour field now clips exactly to arbitrary simple polygons; its field and knot shapes remain simpler than the source. |
| `spring` | M10 | `spring` | Approximate: coil shape and end joins differ. |
| `weight.h`, `weight.s` | M10, S106 | `weight`, `weight-standing` | Approximate: continuous smooth-shouldered tube profiles replace the source's shaped auricle and end details. |
| `lens` profiles | M10, S108 | `lens(right-sag:)` | Approximate: asymmetric, concave and plano profiles are supported; curved faces use sampled spline arcs rather than exact circles. |
| `pulley`, `pulleyWheel`, `wheel` | M8, S107 | `pulley`, `pulley-wheel`, `wheel` | Approximate: native rim, groove and spoke construction replaces source shading and masks. |
| `shapeCenterOfMass` | S107 | `polygon-centroid`, `centroid-marker` | Approximate: standard area centroid for simple polygon vertices. |
| `drawmidarrow`, `markAngle` | S108 | `vector`, `mark-angle` | Approximate: arrow and label placement differ. |
| `refractionPath`, reflection | M11 | `refraction-path` | Approximate: sampled polygon boundaries. |
| `globe`, landmass projection | M11 | `globe` | Approximate: caller-supplied coasts are linearly densified to 5° and clipped at the horizon; built-in coast data and source shading remain out of scope. |
| `eye` | M11 | `eye` | Approximate: configurable anatomy and deterministic lashes; shapes differ from the source. Aspect, gaze and rotation edge cases are shown in `eye.typ`. |
| `knotFromStrands`, styles and layers | M11 | `strand-knot` | Approximate: open and self-crossing polylines support alternating crossings or explicit global layers, including paths with duplicate vertices; tube styles and shadows differ. |

This accounts for the source's public graphical families. Internal helpers
(`offsetPathTemplate`, `tubeGenerate`, `isoLines`, `cLine`, horizon search,
list utilities and 3-D rotation) are in scope when their behavior is needed
to reproduce a family's output; API names need not match.

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
   A project license is still undeclared, so the repository is not yet ready
   to publish until its maintainer chooses the license and attribution text.

After each drawing-code change, compile the focused specimen and `main.typ`.
Keep the pinned, seeded source plates fixed as a common comparison target.

The remaining visual work is the source-plate comparison pass for brush,
sphere, and tube details (roadmap item 1); matching MetaPost's internal
recursion and call counts is still not a completion requirement.
