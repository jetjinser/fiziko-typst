// Exercise variable-radius callbacks across strand-knot crossing fragments.
#import "../fiziko.typ": canvas, strand-knot

#let width-a(t) = 0.65 + 0.45 * t
#let width-b(t) = 1.05 - 0.35 * t
#let paths = (
  ((8, 8), (20, 30), (34, 10), (48, 30)),
  ((8, 30), (20, 10), (34, 30), (48, 8)),
)
#let times = ((0, 1, 2, 3), (0, 1, 2, 3))
#metadata((rendered: true,)) <strand-knot-variable-width>
#canvas(60, 40, strand-knot(paths, widths: (width-a, width-b),
  path-times: times, layers: (1, 0), style: "tube", occlusion: "mask",
  rng: "metapost", seed: 1, rng-offset: 0, source-cubic-step: 0))
