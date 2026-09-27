#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Sphere shadow projection

The left sphere uses an explicit polygon in its projected 2D coordinates. The
right sphere projects a planar occluder along the light vector, accounting for
the depth of each visible surface sample.

#figure(
  canvas(100, 50,
    sphere(26, center: (25, 25), shadow-regions: (
      ((-4, -18), (-2, -18), (-2, 18), (-4, 18)),
    ))
    + sphere(26, center: (75, 25), shadow-planes: (
      sphere-shadow-plane(((-4, -18), (-2, -18), (-2, 18), (-4, 18)), 12),
    )),
  ),
  caption: [Manual projected mask (left) and depth-projected plane (right)],
)

The plane polygon uses sphere-local world XY coordinates with y up. Its depth
is positive toward the viewer, in the same units as the sphere radius. The
`light` vector uses x right, y up, and z toward the viewer.
