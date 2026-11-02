#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Scalar-field isolines

`contour-lines` returns connected polylines for further processing;
`iso-lines` draws them directly. The field is sampled over the given bounds.
An optional cell-center mask excludes regions, and `width:` accepts a constant
brush width or a function of each path's normalized length in millimetres.

#let terrain(x, y) = calc.sin(x * 8deg) + calc.cos(y * 9deg)

#figure(
  canvas(100, 58,
    iso-lines(terrain, 5, 5, 90, 46,
      (-1.2, -0.8, -0.4, 0, 0.4, 0.8, 1.2),
      nx: 90, ny: 46, stroke: 0.35pt + black,
      mask: (x, y) => x < 72,
      width: t => 0.08 + 0.06 * (1 + calc.sin(360 * t)), seed: 1)
    + stroke-path(((5, 5), (95, 5), (95, 51), (5, 51)),
        closed: true, stroke: 0.5pt + black, per: 0),
  ),
  caption: [Connected contours from an analytic scalar field],
)
