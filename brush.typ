#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Brush edge cases

The first plate uses upstream M2's anchor points and exact tapered width
profile; the second uses the
S101 stippled-brush path and width profile. The remaining examples cover a
sharp turn, a sub-minimum short stroke, and a closed loop whose width changes
around the seam.

#let m2 = ((6, 36), (38, 16), (72, 34), (104, 14))
#figure(
  canvas(110, 52,
    stroke-path(m2,
      stroke: (paint: black, thickness: 0.35pt, dash: "dotted"), per: 24)
    + stroke-ink(m2,
      t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
      closed: false, per: 24, seed: 1),
  ),
  caption: [Upstream M2 path and tapered profile with the source's 3 pt amplitude],
)

#figure(
  canvas(120, 44,
    stroke-stipple-brush(((5, 35), (26, 13), (48, 32)),
      t => 0.3 * pt * calc.sin(calc.pi * t),
      closed: false, per: 24, seed: 1),
  ),
  caption: [S101 stippled brush geometry and radian width profile; three-track layout follows thinBrush.stipples],
)

#figure(
  canvas(24, 18,
    stroke-stipple-brush(((8, 9), (16, 9)), 0.11 * pt,
      dot-size: 0.6 * pt, track-spacing: 0.9 * pt,
      closed: false, per: 0, seed: 4),
  ),
  caption: [Sparse stipple tracks exercise the one- and two-dot spacing rule],
)

#figure(
  canvas(100, 50,
    stroke-ink(((8, 38), (16, 10), (24, 38)), 0.55,
      closed: false, per: 0)
    + stroke-ink(((32, 28), (32.5, 28)), 0.05, closed: false, per: 0)
    + stroke-ink(circle-pts(11, 48, center: (68, 25)),
        t => (0.25 + 0.2 * calc.sin(360 * t * 1deg)) * pt,
        closed: true, per: 0),
  ),
  caption: [Acute bend, short hairline, and closed variable-width loop],
)

#figure(
  canvas(100, 38,
    stroke-path(((6, 28), (16, 10), (88, 28)),
      stroke: (paint: black, thickness: 0.35pt, dash: "dotted"), per: 24)
    + stroke-ink(((6, 28), (16, 10), (88, 28)),
      t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
      closed: false, per: 24),
  ),
  caption: [Width profile parameterized by arc length across unequal spans],
)
