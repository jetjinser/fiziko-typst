#import "../fiziko.typ": canvas, sphere-stipple-rings, stroke-stipple-brush, pt, tube

#let density = float(sys.inputs.at("density", default: "0.56"))
#let sphere-density = float(sys.inputs.at("sphere-density", default: "0.55"))
#let brush-density = float(sys.inputs.at("brush-density", default: "0.5"))
#set page(width: 120mm, height: 44mm, margin: 0pt)

#canvas(120, 44,
  stroke-stipple-brush(((5, 35), (26, 13), (48, 32)),
    t => 0.3 * pt * calc.sin(calc.pi * t),
    closed: false, per: 48, density: brush-density, seed: 1)
  + sphere-stipple-rings(22, center: (70, 22), seed: 1, density: sphere-density)
  + tube(((89, 33), (103, 10), (115, 28)), 3,
    hatch: "s", per: 48, seed: 1, dot-density: density),
)
