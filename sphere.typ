#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Concentric sphere shading

The 26 mm sphere uses the default light from the pinned M5 source plate. Ring
count follows the source's power-of-two spacing rule, with residual-aware
thin-ring compensation. Ring paths use 128 arc samples by default; `samples:`
can be raised for unusually large output.

#figure(
  canvas(110, 56,
    sphere(26, center: (55, 28), seed: 1),
  ),
  caption: [Concentric-ring sphere at the upstream source diameter],
)

#figure(
  canvas(110, 56,
    sphere-stipple-rings(22, center: (31, 28), seed: 1)
    + sphere-stipple(22, center: (79, 28), seed: 1),
  ),
  caption: [Source-style concentric stipples beside the jittered 2D field],
)

#figure(
  canvas(120, 44,
    sphere-stipple-rings(22, center: (70, 22), seed: 1),
  ),
  caption: [Concentric stipple sphere at the exact upstream S101 frame and position],
)
