#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Telescope composite

A compact composite assembled from the existing tube, lens, stroke, and label
primitives. The dashed optical axis and support are ordinary Typst-native
strokes; no telescope-specific API is needed.

#figure(
  canvas(120, 58,
    tube(((24, 26), (90, 26)), 4.5, hatch: "l", spacing: 1.8, per: 16)
    + lens(17, 2.2, rim: 2, axis: 7, at: (22, 26))
    + lens(12, 1.5, rim: 1.8, axis: 5, at: (92, 26))
    + stroke-path(((12, 26), (108, 26)),
        stroke: (paint: black, thickness: 0.35pt, dash: "dashed"), per: 0)
    + stroke-path(((55, 31), (50, 49), (61, 49), (55, 31)), per: 0)
    + stroke-path(((45, 49), (66, 49)), per: 0)
    + tag([Objective], (22, 12), anchor: center)
    + tag([Eyepiece], (92, 12), anchor: center)
    + tag([Optical axis], (61, 35), anchor: left),
  ),
  caption: [A telescope built by composing existing primitives],
)
