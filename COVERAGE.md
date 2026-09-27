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
| Sphere cast-shadow regions | S102 | `sphere` / `sphere-stipple` `shadow-regions:` and `shadow-planes:` | Approximate: local masks remain supported; planar occluders now project along the light direction onto visible sphere samples. Arbitrary 3D occluders and exact path splitting remain open. |
| `solidSurface`, `solid`, `gradientShade` | S103 | `solid-surface`, `solid`, `gradient-shade` | Approximate: scanline clipping is polygon-native; glass gaps and gradient widths differ from source. |
| `flatSurface.hatches`, `.stipples` | S104 | `flat-surface(style: "hatch"/"stipples")` | Approximate: Lambert shade and boundary fade control deterministic clipped strokes or stipples. |
| `woodBlock`, `woodenThing`, `woodenSurface` | M9, S105 | `wood-block`, `wooden-surface`, `wood` | Approximate: wood field and band clipping are simplified; arbitrary woodenThing clipping remains open. |
| `spring` | M10 | `spring` | Approximate: coil shape and end joins differ. |
| `weight.h`, `weight.s` | M10, S106 | `weight`, `weight-standing` | Approximate: both use tapered tube primitives and simplified end profiles. |
| `lens` profiles | M10, S108 | `lens` | Approximate: asymmetric, concave and infinite-radius cases differ. |
| `pulley`, `pulleyWheel`, `wheel` | M8, S107 | `pulley`, `pulley-wheel`, `wheel` | Approximate: native rim, groove and spoke construction replaces source shading and masks. |
| `shapeCenterOfMass` | S107 | `polygon-centroid`, `centroid-marker` | Approximate: standard area centroid for simple polygon vertices. |
| `drawmidarrow`, `markAngle` | S108 | `vector`, `mark-angle` | Approximate: arrow and label placement differ. |
| `refractionPath`, reflection | M11 | `refraction-path` | Approximate: sampled polygon boundaries. |
| `globe`, landmass projection | M11 | `globe` | Partial: built-in coasts, source shading and horizon behavior missing. |
| `eye` | M11 | `eye` | Approximate: anatomy, lashes and randomness differ. |
| `knotFromStrands`, styles and layers | M11 | `strand-knot` | Partial: tube styles, crossing layers and shadows differ. |

This accounts for the source's public graphical families. Internal helpers
(`offsetPathTemplate`, `tubeGenerate`, `isoLines`, `cLine`, horizon search,
list utilities and 3-D rotation) are in scope when their behavior is needed
to reproduce a family's output; API names need not match.

The manual also has complex *composite examples*, including a telescope.
Those need separate reference plates after their component families work;
they are not claimed complete by this inventory. M8, M5 and M10 already
cover smaller pulley and physics compositions.

## Next order

1. Refine brush, sphere and tube details where visual differences matter; keep
   the Typst-native algorithms when they perform better.
2. Extend sphere shadows to arbitrary 3D occluders and improve tube, wood and
   mechanical details where examples expose visible gaps.
3. Match globe, eye, knots and optics, then add the manual's composites.

After each drawing-code change, compile the focused specimen and `main.typ`.
Keep the pinned, seeded source plates fixed as a common comparison target.
