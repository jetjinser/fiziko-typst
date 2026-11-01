#import "../fiziko.typ": arc-pts, canvas, pt, tube

#set page(width: 110mm, height: 56mm, margin: 0pt)

#canvas(110, 56,
  tube(arc-pts(42, 205, 335, n: 40, center: (55, 68)), 6,
    per: 4, seed: 1, max-w: 0.308 * pt),
)
