#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Globe projection edge cases

Land paths are linearly interpolated in longitude and latitude, then sampled
at no more than 5° per segment before horizon clipping. Even coarse paths can
cross the visible hemisphere when both endpoints are hidden.

#v(8mm)
#figure(
  canvas(110, 54,
    globe(48,
      lands: (((-150, 20), (150, 20)),),
      center: (28, 27),
    )
    + globe(30,
      rotation: (65, 20),
      lands: (((-80, -25), (-40, -5), (-15, 22), (10, 18),
                (35, -2), (70, -12)),),
      center: (83, 27),
    ),
  ),
  caption: [A coarse back-to-front path and a rotated globe with a caller-supplied coast],
)
