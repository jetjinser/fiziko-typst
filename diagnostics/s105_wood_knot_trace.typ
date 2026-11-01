// Compare the source-traced S105 woodenSurface cursor and first knot.
#import "../fiziko.typ": _woodblock-field

// Source WOODANGLE reports 147.4013 x 23.46558 bp, about 52 x 8.28 mm.
// woodBlock rounds to 52 x 8 mm and swaps the internal axes for this face.
#let field = _woodblock-field(8, 52, 1, rng-offset: 536)
#let output-knots = field.knots.map(k => (k.at(1), 8 - k.at(0)))
#metadata((internal-knots: field.knots, output-knots: output-knots,
  rng-count: field.rng-count)) <s105-wood-knot-trace>
