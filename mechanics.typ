#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Mechanical drawing edge cases

These specimens compare small and large primitives, both weight orientations,
and the available symmetric and asymmetric lens profiles.

#figure(
  canvas(116, 50,
    spring((10, 8), (10, 40), coils: 7, rad: 2.2, lead: 3)
    + weight(20, r: 3.6, at: (28, 10))
    + weight-standing(20, r: 3.6, taper: 0.4, at: (47, 10))
    + lens(17, 2.2, rim: 3.5, at: (72, 25))
    + lens(17, 5, right-sag: 7, rim: 3.5, at: (89, 25))
    + pulley(14, center: (107, 14))
    + wheel(18, spokes: 8, center: (107, 39)),
  ),
  caption: [Spring, hanging and standing weights, concave and asymmetric lenses, pulley and wheel],
)
