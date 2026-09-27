#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Sphere shadow projection

The first sphere uses an explicit 2D mask. The middle sphere projects an XY
plane along the light vector. The last sphere uses a tilted 3D polygon.

#figure(
  canvas(140, 50,
    sphere(26, center: (25, 25), shadow-regions: (
      ((-4, -18), (-2, -18), (-2, 18), (-4, 18)),
    ))
    + sphere(26, center: (75, 25), shadow-planes: (
      sphere-shadow-plane(((-4, -18), (-2, -18), (-2, 18), (-4, 18)), 12),
    ))
    + sphere(26, center: (125, 25), shadow-polygons: (
      sphere-shadow-polygon(((-5, -18, 14), (-3, -18, 14),
                             (-3, 18, 13), (-5, 18, 13))),
    ))
  ),
  caption: [Manual mask (left), XY plane (middle), and tilted 3D polygon (right)],
)

`sphere-shadow-plane` accepts a 2D polygon in sphere-local XY coordinates
(y up) and its depth. `sphere-shadow-polygon` accepts coplanar 3D vertices in
the same local coordinates. Its plane can have any orientation; the polygon
must be simple with at least three non-collinear vertices. Both use positive z
toward the viewer and the sphere's radius units. The `light` vector uses x
right, y up, and z toward the viewer.

#figure(
  canvas(140, 40,
    sphere-latitude(28, latitude: -25, center: (25, 20))
    + sphere-latitude(28, latitude: -25, center: (75, 20), shadow-polygons: (
      sphere-shadow-polygon(((-5, -18, 14), (-3, -18, 14),
                             (-3, 18, 13), (-5, 18, 13))),
    ))
    + sphere-stipple(28, center: (125, 20), dot-step: 0.65, dot-size: 0.9 * pt,
        shadow-polygons: (
          sphere-shadow-polygon(((-5, -18, 12), (-3, -18, 12),
                                 (-3, 18, 11), (-5, 18, 11))),
        )),
  ),
  caption: [Tilted 3D polygon shadow on latitude hatching and sphere stipple],
)
