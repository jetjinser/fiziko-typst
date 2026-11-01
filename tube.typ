#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Tube hatching and stipple

The first tube matches upstream Figure 4's 110 × 56 mm geometry. The second
matches the variable-radius ring and cone from upstream Figure 6.

#figure(
  canvas(110, 56,
    tube(arc-pts(42, 205, 335, n: 40, center: (55, 68)), 6,
      per: 4, seed: 1, max-w: 0.308 * pt),
  ),
  caption: [Constant-radius arc with source-scale longitudinal hatching],
)

#figure(
  canvas(110, 62,
    tube(circle-pts(24, 96, center: (32, 31)),
      // `circle-pts` runs clockwise on screen; reverse the source phase.
      t => 3.5 - 1.8 * calc.sin(360 * 5 * t * 1deg),
      closed: true, per: 2, seed: 1)
    + tube(((85, 10), (85, 52)), t => (1 - t) * 9, per: 8, seed: 1),
  ),
  caption: [Oscillating-radius closed tube and a taper with slope-aware lightness],
)

#figure(
  canvas(110, 42,
    tube(((6, 32), (40, 14), (74, 32), (104, 16)), 5,
      hatch: "t", per: 384, seed: 1, period: 0.90 * pt),
  ),
  caption: [Transverse tube hatching with cross-section lightness and variable ink width],
)

#figure(
  canvas(120, 44,
    tube(((89, 33), (103, 10), (115, 28)), 3,
      hatch: "s", per: 48, seed: 1),
  ),
  caption: [Stippled tube using the upstream S101 geometry],
)

#figure(
  canvas(100, 44,
    tube(((6, 37), (31, 12), (60, 36), (94, 14)),
      t => 0.9 + 1.6 * (1 - t), hatch: "s", per: 12, seed: 5),
  ),
  caption: [Stipple tracks through a curved taper and changing lane density],
)
