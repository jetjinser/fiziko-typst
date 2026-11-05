// Compare M9's four source woodBlock knot streams independently.
#import "../fiziko.typ": _woodblock-field

#let offsets = (0, 1456, 2823, 4120)
#metadata(offsets.map(offset => {
  let field = _woodblock-field(33, 55, 1, source-res: 1,
    rng-offset: offset)
  (offset: offset, knots: field.knots, rng-count: field.rng-count)
})) <m9-wood-knot-panel-trace>
