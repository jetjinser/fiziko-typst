#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Grain in an arbitrary outline

Wood contours are sampled from a scalar field and clipped exactly to each
outline segment. Concave polygons work as well as rectangles and raised bands.

#figure(
  canvas(100, 50,
    wooden-thing(
      ((10, 8), (84, 8), (84, 15), (68, 15), (68, 40), (45, 40), (45, 28), (10, 28)),
      angle: 0,
      spacing: 2.6,
      eyes: ((33, 8, 4.2),),
      cell: 0.7,
    ),
  ),
  caption: [Concave wooden outline with one knot],
)
