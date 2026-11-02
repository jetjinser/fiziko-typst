// Source's internal landscape block and its output-space knot coordinates.
#import "../fiziko.typ": _woodblock-field

#let field = _woodblock-field(33, 55, 1, source-res: 1)
#let output-knots = field.knots.map(k => (k.at(1), 33 - k.at(0)))
#metadata((internal-knots: field.knots, output-knots: output-knots,
  rng-count: field.rng-count)) <m9-wood-knot-trace>
