#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Strand crossings

Zero-length input segments are ignored when finding crossings. Widths can be
set per strand; numeric layers give a fixed over-under order.

#figure(
  canvas(100, 48,
    strand-knot((
      ((8, 10), (48, 38), (8, 38)),
      ((48, 10), (8, 24), (48, 38)),
      ((28, 8), (28, 24), (28, 24), (28, 40)),
    ), widths: (1.1, 0.9, 0.8), layers: (3, 2, 1), gap: 0.8)
    + strand-knot((
      ((69, 10), (89, 40), (69, 40), (89, 10), (69, 10)),
    ), widths: 1.1, seed: 8),
  ),
  caption: [Three fixed layers, including a duplicate vertex, and a self-crossing closed strand],
)
