#import "../fiziko.typ": canvas, stroke-stipple-brush, pt

#let scale = float(sys.inputs.at("scale", default: "1.0"))
#let density = float(sys.inputs.at("density", default: "0.5"))
#let point(x, y) = (60 + (x - 26.5) * scale, 22 + (y - 24) * scale)
#set page(width: 120mm, height: 44mm, margin: 0pt)

#canvas(120, 44,
  stroke-stipple-brush((point(5, 35), point(26, 13), point(48, 32)),
    t => 0.3 * pt * calc.sin(calc.pi * t),
    closed: false, per: 48, density: density, seed: 1),
)
