#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Lens profiles

The two sides can have different sagittae. Matching a side's sagittal offset
to the rim makes that surface flat; a larger offset makes it convex, while a
smaller one makes it concave.

#figure(
  canvas(100, 48,
    lens(22, 3, at: (16, 24))
    + lens(22, 2, rim: 4, at: (50, 24))
    + lens(22, 4, right-sag: 6, rim: 4, at: (84, 24)),
  ),
  caption: [Symmetric convex, symmetric concave, and plano-convex profiles],
)

#figure(
  canvas(100, 52,
    stroke-path(circle-pts(18, 96, center: (50, 27)), closed: true, per: 0)
    + refraction-path(((8, 19), (32, 19)), circle-pts(18, 96, center: (50, 27)),
        ior: 1.5, bounces: 3, max-length: 45)
    + refraction-path(((47, 40), (50, 40)), circle-pts(18, 96, center: (50, 27)),
        ior: 1.5, bounces: 4, max-length: 45),
  ),
  caption: [A refracted ray and a second ray undergoing total internal reflection],
)
