// Validate the fixed-direction Hobby segment on the traced M11 shadow splice.
#import "../fiziko.typ": _dist, _hobby-given-cubic, _mp-fixed-cubic-arc-raw, _mp-unit

#let cubic = _hobby-given-cubic(
  (86.67961855619988, 21.4557625),
  (86.71295197855189, 21.380763713948124),
  (0.33335673510374797, -0.75),
  (0.33330253500001983, -0.749972535000001),
)
#let arc-fixed = _mp-fixed-cubic-arc-raw(cubic.map(point =>
  point.map(axis => axis / _mp-unit)))
#let source-controls = ((86.69072137201178, 21.43076152897923),
  (86.70183182520415, 21.405763009296393))
#let control-errors = (
  _dist(cubic.at(1), source-controls.at(0)),
  _dist(cubic.at(2), source-controls.at(1)),
)
#metadata((cubic: cubic, control-errors: control-errors,
  arc-fixed: arc-fixed, source-arc-fixed: 15246)) <m11-hobby-given-join>
