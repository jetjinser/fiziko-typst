#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _mp-circle-point, _path-fractions, _source-dash-length, _source-min-stroke, _sin
#import "wood_fullcircle_path.typ": upstream-wood-fullcircle

#let source-step-denominator = 32
#let diameter-step = 8 * _source-min-stroke
#let ring-count = int(calc.floor((2 * 1.25 - 2 * _source-min-stroke) / diameter-step)) + 1
#let stream = _metapost-rng-sequence(1, 4096)
#let source-fullcircle-counts = ()
#let cursor = 0
#let counts = ()
#let max-path-error = 0.0
#for i in range(ring-count) {
  let diameter = 2 * 1.25 - i * diameter-step
  let points = range(8 * source-step-denominator).map(j => {
    let circle = _mp-circle-point(j / source-step-denominator)
    (circle.at(1) * diameter, -circle.at(0) * diameter / _sin(60))
  })
  for j in range(points.len()) {
    let source = upstream-wood-fullcircle.at(j)
    let candidate = points.at(j)
    let error = calc.sqrt(calc.pow(candidate.at(0) / diameter - source.at(0), 2)
      + calc.pow(candidate.at(1) / diameter * _sin(60) - source.at(1), 2))
    max-path-error = calc.max(max-path-error, error)
  }
  let widths-at-source-knots = range(9).map(k => _source-min-stroke *
    (1 / 2 + _sin(60) * calc.abs(_sin(45 * k))))
  let fractions = _path-fractions(points, true)
  let source-times = range(9).map(k => if k == 8 { 1.0 }
    else { fractions.at(k * source-step-denominator) })
  let width(t) = {
    let j = range(8).find(j => source-times.at(j) <= t and t <= source-times.at(j + 1))
    let j = if j == none { 7 } else { j }
    let lo = source-times.at(j)
    let hi = source-times.at(j + 1)
    let f = if hi > lo { (t - lo) / (hi - lo) } else { 0.0 }
    widths-at-source-knots.at(j) * (1 - f) + widths-at-source-knots.at(j + 1) * f
  }
  let result = _ink-loops(_frame(points, true), fractions.map(width), true,
    _source-min-stroke, _source-dash-length, random-stream: stream,
    rng-offset: cursor, with-rng: true, with-stats: true,
    source-rounding: true, width-by-arc: true)
  cursor += result.at(1)
  counts.push(result.at(1))
}
#source-fullcircle-counts.push((path-step: 1 / source-step-denominator,
  ring-counts: counts, total: counts.sum(), max-unit-path-error: max-path-error))

#metadata(source-fullcircle-counts) <wood-knot-fullcircle-counts>
