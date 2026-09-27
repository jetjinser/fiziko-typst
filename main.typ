#import "fiziko.typ": *

#set document(
  title: "fiziko.typ — MetaPost-style drawing for Typst",
  author: "experiment",
)
#set page(paper: "a4", margin: (x: 22mm, top: 24mm, bottom: 22mm), numbering: "— 1 —")
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10.5pt)
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.")
#set figure.caption(separator: [ — ])

#align(center)[
  #text(17pt, weight: "bold")[fiziko.typ] \
  #text(11pt)[MetaPost-style programmatic figures for Typst]
]
#align(center)[
  #v(1.5mm)
  #text(size: 9.5pt, style: "italic")[
    Offset curves, ink-conserving brushes, hatched spheres, tubes —
    a first pass after jemmybutton/fiziko
  ]
]
#v(4mm)

#figure(
  canvas(
    110, 52,
    stroke-path(((6, 36), (38, 16), (72, 34), (104, 14)),
                stroke: 0.6pt + black, per: 24)
    + stroke-path(
      offset-path(((6, 36), (38, 16), (72, 34), (104, 14)),
                  t => 7 * calc.sin(180 * t * 1deg), closed: false, per: 24),
      stroke: (paint: black, thickness: 0.5pt, dash: "dashed"), per: 0,
    ),
  ),
  caption: [
    An anchor-point curve and its offset at a varying distance: the primitive
    behind every variable-width stroke (after MetaPost figs. 3 and 4).
  ],
)

#figure(
  canvas(
    110, 52,
    stroke-path(((6, 36), (38, 16), (72, 34), (104, 14)),
                stroke: (paint: black, thickness: 0.35pt, dash: "dotted"), per: 24)
    + stroke-ink(
      ((6, 36), (38, 16), (72, 34), (104, 14)),
      t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
      closed: false, per: 24,
    ),
  ),
  caption: [
    Variable-width brush. Where the intended line falls below the printable
    minimum of 0.3pt it is replaced by dashes of the same hairline
    weight, carrying the same amount of ink per unit length (MetaPost fig. 5).
  ],
)

#figure(
  canvas(
    110, 56,
    sphere-latitude(20, latitude: -60, center: (36, 28))
    + sphere-latitude(30, latitude: 45, center: (70, 28)),
  ),
  caption: [
    Latitudinal sphere hatching at −60° and 45°; the latitude
    changes both the projected arcs and their density compensation.
  ],
)

#figure(
  canvas(
    110, 56,
    tube(arc-pts(42, 205, 335, n: 60, center: (55, 68)), 6, spacing: 1.8, per: 0),
  ),
  caption: [
    A tube: two offset outlines plus longitudinal lines whose number follows the
    radius (MetaPost fig. 7).
  ],
)

#figure(
  canvas(
    110, 82,
    stroke-ink(((14, 6), (78, 6)), 1.0, closed: false, per: 8)
    + combine(range(9).map(i => stroke-path(
      ((20 + 6.5 * i, 6), (16.5 + 6.5 * i, 1.5)),
      stroke: 0.4pt + black, per: 4,
    )))
    + tube(((35, 6), (59.4, 51.9)), 1.0, spacing: 1.8, per: 8)
    + mark-angle((35, 20), (35, 6), (59.4, 51.9), r: 7.5)
    + sphere(26, light: (-0.45, 0.5, 0.75), center: (59.4, 51.9))
    + vector((59.4, 66.5), (59.4, 78), w: 0.5, head: 2.8)
    + tag($A$, (31, 3.5), anchor: bottom + right)
    + tag($theta$, (37.6, 16.3))
    + tag($l$, (51.2, 26.9))
    + tag($m$, (76.4, 49.9))
    + tag($m g$, (65, 76)),
  ),
  caption: [
    Composition: hatched ceiling, tube string, hatched sphere as weight, a
    marked angle and the $m g$ vector — all TeX labels. Every position above
    is an expression of the same few numbers — move $l$ or $theta$ and the
    geometry follows (cf. MetaPost fig. 18).
  ],
)

#figure(
  canvas(
    110, 62,
    tube(circle-pts(24, 96, center: (32, 31)),
         t => 3.5 + 1.8 * calc.sin(360 * 5 * t * 1deg),
         closed: true, per: 2, spacing: 1.8)
    + tube(((85, 10), (85, 52)), t => (1 - t) * 9, spacing: 1.8, per: 8),
  ),
  caption: [
    Tubes of varying radius: a closed ring whose radius oscillates (MetaPost
    fig. 8) and a cone (fig. 10). Interior lines are placed as fractions of the
    *local* radius and weighted by the local ink budget, so they converge with
    the taper and thin out into hairline dashes at the tip.
  ],
)

#figure(
  canvas(
    110, 42,
    tube(((6, 32), (40, 14), (74, 32), (104, 16)), 5,
         hatch: "t", spacing: 2.2, per: 24),
  ),
  caption: [
    Transverse hatching (MetaPost fig. 9): spacing and thickness are coupled so
    ink per unit area stays constant; below the 0.3 pt minimum the
    thickness is clamped and the spacing grows instead of the line vanishing.
  ],
)

#figure(
  canvas(
    110, 40,
    l-hopital-pulley(6, 2, 11 / 2, at: (8, 6))
    + l-hopital-pulley(3, 5 / 2, 3, at: (58, 6)),
  ),
  caption: [
    L'Hôpital's pulley (MetaPost fig. 18). The axle hangs at $D$, where the
    rope of length $l$ from $A$ meets the rope of length $m$ running
    $B$–$D$–$C$; equilibrium gives a closed form for the position of $D$, and
    the wheel centre is the intersection of two offset lines — the same linear
    system MetaPost solves with `whatever`. Two parameter sets, one function.
  ],
)

#figure(
  canvas(
    110, 66,
    wood(0, 0, 55, 33, angle: 0, eyes: ((40, 17, 5.5),))
    + wood(55, 0, 55, 33, angle: 90, eyes: ((18, 12, 4.5),))
    + wood(0, 33, 55, 33, angle: 90, eyes: ((34, 21, 4.5),))
    + wood(55, 33, 55, 33, angle: 0, eyes: ((14, 12, 5.5),)),
  ),
  caption: [
    Wood grain as level sets (MetaPost fig. 16): the rings are the contour
    lines of parallel planes, each eye contributing a log *twig function* that
    makes the rings wrap the knot. Four planks, four directions, one field —
    computed by marching squares and clipped to each rectangle.
  ],
)

#figure(
  canvas(
    110, 58,
    // left: ceiling, spring, weight, m·g vector
    stroke-ink(((8, 6), (30, 6)), 0.9, closed: false, per: 4)
    + combine(range(5).map(i => stroke-path(
      ((11 + 4.5 * i, 6), (9.5 + 4.5 * i, 3.5)),
      stroke: 0.4pt + black, per: 2,
    )))
    + spring((19, 6), (19, 30), coils: 7, rad: 2.4, lead: 3)
    + weight(14, r: 4.2, at: (19, 30))
    + vector((19, 45.5), (19, 54), w: 0.35, head: 2.6)
    + tag($k$, (25, 17))
    + tag($m g$, (23.5, 52))
    // right: lens, optical axis, ray, angle mark
    + lens(20, 3.2, axis: 20, at: (72, 30))
    + vector((52, 24), (68.5, 24), w: 0.3, head: 2.2)
    + vector((74.5, 24), (86, 33.6), w: 0.3, head: 2.2)
    + stroke-path(circle-pts(0.4, 20, center: (82, 30)),
                  stroke: 0.4pt + black, closed: true, per: 0)
    + mark-angle((76, 30), (82, 30), (77.3, 26.3), r: 6, ticks: 1)
    + tag($F$, (84.5, 36))
    + tag($f$, (78.6, 32.8))
    + tag($i$, (75.6, 27.7)),
  ),
  caption: [
    Physics primitives, one call each: a helical spring and a hatched
    calibration weight with its $m g$ vector; a thin lens on its dashed
    optical axis, a parallel ray refracted through the focal point $F$, and
    the angle of incidence marked with a tick — MetaPost's `drawmidarrow` and
    `markAngle` equivalents.
  ],
)

= The figure is a function

Nothing in the examples above is drawn by hand. Figure 2 in full:

```typst
#import "fiziko.typ": *

#let p = ((6, 36), (38, 16), (72, 34), (104, 14))

#canvas(110, 52,
  stroke-path(p, stroke: 0.6pt + black, per: 24)
  + stroke-ink(p,
      t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
      closed: false, per: 24, seed: 42))
```

Coordinates are plain millimetre floats, so a figure can be regrown for any
column width by changing one number, and the width law is an ordinary Typst
function of the position along the path.

= Print notes

Preflight of this document is reproducible with `./preflight.sh`
(qpdf, pdffonts, Ghostscript); the measured facts:

- *Minimum weight.* Ordinary strokes use a 0.3pt minimum; the latitude sphere
  follows fiziko's source defaults (0.2pt pen, 0.3pt maximum shading width,
  0.9pt line spacing). Measured stroked paths in this file are 0.35, 0.4,
  0.45, 0.5, and 0.6pt; source-matched sphere hatches are filled 0.2pt paths.
- *Colour.* Figure and text use solid black in the master; preflight found 314
  black-gray `scn` operations. The only visible color is the code listing's
  syntax highlighting (44 non-gray `scn` values and two `k` operators);
  `main-gray.pdf` is a converted single-K candidate from the
  earlier four-page specimen and needs regeneration from this build.
- *Fonts.* All five fonts (NewCM roman/italic/bold, NewCM Math, DejaVu Sans
  Mono) are embedded as subsets with Unicode maps.
- *Structure.* The specimen is five pages. Current qpdf/Ghostscript checks
  pass; it has no transparency, images, annotations, or encryption, and the
  page size is exact A4.
- *PDF/X.* Typst does not emit PDF/X yet (typst/typst#6012): this file has
  no OutputIntent. For delivery, convert where a CMYK profile and veraPDF
  are available, e.g.
  `gs -sDEVICE=pdfwrite -dPDFX -sOutputICCProfile=FOGRA39L_coated.icc ...`,
  and verify the result with veraPDF before press.

= Next

- extend seeded variation to geometric jitter and stipple patterns,
- add broader physics composites, shadows, and surface stippling.

= Globe, eye, knots, and refraction

#let weave-a = range(81).map(i => {
  let t = i / 80
  (86 + 32 * t, 22 + 6 * calc.sin(720 * t * 1deg))
})
#let weave-b = range(81).map(i => {
  let t = i / 80
  (86 + 32 * t, 22 - 6 * calc.sin(720 * t * 1deg))
})
#let refractor = circle-pts(10, 80, center: (136, 22))

#figure(
  canvas(155, 44,
    globe(30,
      lands: (((-55, -20), (-38, -10), (-25, 8), (-12, 20),
              (3, 24), (18, 15), (22, 0), (10, -12), (-12, -18), (-55, -20)),),
      center: (19, 22))
    + eye(at: (62, 22), size: (28, 14), look: (0.45, -0.15), seed: 17)
    + strand-knot((weave-a, weave-b), widths: 0.8, gap: 0.6, seed: 21)
    + stroke-path(refractor, closed: true, per: 0)
    + refraction-path(((122, 17), (128, 17)),
        refractor, ior: 1.5,
        max-length: 15)),
  caption: [Orthographic globe with a caller-supplied coast, deterministic anatomical eye, alternating strand crossings, and a ray refracted through a circular boundary.]
)
