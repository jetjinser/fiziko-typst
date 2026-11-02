#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _path-fractions, _source-dash-length, _source-min-stroke, _sin

#let samples = (8, 16, 24, 32, 64, 96)
#let diameter-step = 8 * _source-min-stroke
#let ring-count = int(calc.floor((2 * 1.25 - 2 * _source-min-stroke) / diameter-step)) + 1
#let stream = _metapost-rng-sequence(1, 4096)
#let resolution-counts = ()
#for sample-count in samples {
  let cursor = 0
  let counts = ()
  for i in range(ring-count) {
    let diameter = 2 * 1.25 - i * diameter-step
    let rx = diameter / 2
    let ry = diameter / (2 * _sin(60))
    let points = range(sample-count).map(j => {
      let a = 360 * j / sample-count
      (rx * calc.cos(a), ry * calc.sin(a))
    })
    let frames = _frame(points, true)
    let fractions = _path-fractions(points, true)
    // offsetPathTemplate samples the source width at the fullcircle's eight
    // path knots, then linearly joins those values by centerline arc length.
    let source-widths = range(9).map(k => _source-min-stroke *
      (1 / 2 + _sin(60) * calc.abs(_sin(45 * k))))
    let source-times = range(9).map(k => if k == 8 { 1.0 }
      else { fractions.at(int(k * sample-count / 8)) })
    let width(t) = {
      let j = range(8).find(j => source-times.at(j) <= t and
        t <= source-times.at(j + 1))
      let j = if j == none { 7 } else { j }
      let lo = source-times.at(j)
      let hi = source-times.at(j + 1)
      let f = if hi > lo { (t - lo) / (hi - lo) } else { 0.0 }
      source-widths.at(j) * (1 - f) + source-widths.at(j + 1) * f
    }
    let result = _ink-loops(frames, fractions.map(width), true,
      _source-min-stroke, _source-dash-length, random-stream: stream,
      rng-offset: cursor, with-rng: true, with-stats: true,
      source-rounding: true)
    cursor += result.at(1)
    counts.push(result.at(1))
  }
  resolution-counts.push((sample-count: sample-count, ring-counts: counts,
    total: counts.sum()))
}

#metadata(resolution-counts) <wood-knot-resolution-counts>
