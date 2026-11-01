// Isolate Figure 11 components with a fixed origin and matching --root.
#import "/fiziko.typ": *
#set page(width: 155mm, height: 44mm, margin: 0pt)
#let weave-a = range(81).map(i => {
  let t = i / 80
  (86 + 32 * t, 22 + 6 * calc.sin(720 * t * 1deg))
})
#let weave-b = range(81).map(i => {
  let t = i / 80
  (86 + 32 * t, 22 - 6 * calc.sin(720 * t * 1deg))
})
#let refractor = circle-pts(10, 80, center: (136, 22))

#let case = sys.inputs.at("case")
#canvas(155, 44,
  if case == "globe" {
    globe(30, lands: (((-55, -20), (-38, -10), (-25, 8), (-12, 20),
      (3, 24), (18, 15), (22, 0), (10, -12), (-12, -18), (-55, -20)),), center: (19, 22))
  } else if case == "eye" {
    eye(at: (62, 22), size: (28, 14), look: (0.45, -0.15), seed: 17)
  } else if case == "knot" {
    strand-knot((weave-a, weave-b), widths: 0.8, gap: 0.6, seed: 21)
  } else {
    (stroke-path(refractor, closed: true, per: 0)
    + refraction-path(((122, 17), (128, 17)), refractor, ior: 1.5, max-length: 15))
  }
)
