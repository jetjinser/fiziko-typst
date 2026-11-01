#import "../fiziko.typ": canvas, tube

#let density = float(sys.inputs.at("density"))
#set page(width: 120mm, height: 44mm, margin: 0pt)

#canvas(120, 44,
  tube(((89, 33), (103, 10), (115, 28)), 3,
    hatch: "s", per: 48, seed: 1, dot-density: density),
)
