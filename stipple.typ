#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Stippled brush, sphere and tube

This plate follows upstream S101's 120 × 44 mm frame, anchor points,
diameters and width profile. `per: 48` gives a useful accuracy and cost
balance for these curved paths; the library defaults remain lower for general
use.

#figure(
  canvas(120, 44,
    stroke-stipple-brush(((5, 35), (26, 13), (48, 32)),
      t => 0.3 * pt * calc.sin(calc.pi * t),
      closed: false, per: 48, seed: 1)
    + sphere-stipple-rings(22, center: (70, 22), seed: 1)
    + tube(((89, 33), (103, 10), (115, 28)), 3,
      hatch: "s", per: 48, seed: 1),
  ),
  caption: [S101 geometry using seeded Typst stipple primitives],
)
