#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Brush edge cases

The examples cover a sharp turn, a sub-minimum short stroke, and a closed loop
whose width changes around the seam.

#figure(
  canvas(100, 50,
    stroke-ink(((8, 38), (16, 10), (24, 38)), 0.55, per: 0)
    + stroke-ink(((32, 28), (32.5, 28)), 0.05, closed: false, per: 0)
    + stroke-ink(circle-pts(11, 48, center: (68, 25)),
        t => (0.25 + 0.2 * calc.sin(360 * t * 1deg)) * pt,
        closed: true, per: 0),
  ),
  caption: [Acute bend, short hairline, and closed variable-width loop],
)
