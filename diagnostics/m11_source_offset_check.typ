// Compare the Typst offsetPathGenerate port against traced source q2/q3 cubics.
#import "../fiziko.typ": _dist, _mp-cubic-split, _mp-fixed-cubic-from-fifth-samples-raw, _mp-fixed-mix-point, _mp-offset-boundary, _mp-unit
#import "../comparisons/m11-knot-paths.typ": upstream-m11-knot-paths

#let cubic-subsegment(curve, from, to) = {
  let prefix = if to >= 1 - 1e-12 { curve }
    else { _mp-cubic-split(curve, to).left }
  if from <= 1e-12 { prefix }
  else { _mp-cubic-split(prefix, from / to).right }
}
#let cubic-subdivide(curve, count) = {
  let output = ()
  let remaining = curve
  for i in range(count - 1) {
    let pieces = _mp-cubic-split(remaining, 1 / (count - i))
    output.push(pieces.left)
    remaining = pieces.right
  }
  output.push(remaining)
  output
}
#let source-fragment-curves(points, times, start, finish, step) = {
  let intervals = step * 4
  if (step < 4 or step != int(step) or calc.rem(step, 4) != 0
      or points.len() != times.len() or points.len() < intervals + 1
      or calc.rem(points.len() - 1, intervals) != 0 or finish <= start) {
    return none
  }
  let valid = true
  for segment in range(int((points.len() - 1) / intervals)) {
    let base = segment * intervals
    let t0 = times.at(base)
    let t1 = times.at(base + intervals)
    for j in range(intervals + 1) {
      if calc.abs(times.at(base + j) - (t0 + (t1 - t0) * j / intervals)) > 1e-8 {
        valid = false
      }
    }
  }
  if not valid { return none }
  let output = ()
  for segment in range(int((points.len() - 1) / intervals)) {
    let base = segment * intervals
    let t0 = times.at(base)
    let t1 = times.at(base + intervals)
    let clip-start = calc.max(start, t0)
    let clip-finish = calc.min(finish, t1)
    if clip-finish > clip-start + 1e-10 {
      let samples = (0, int(step), int(2 * step), int(3 * step), intervals).map(i => {
        let point = points.at(base + i)
        (point.at(0) / _mp-unit, -point.at(1) / _mp-unit)
      })
      let curve = _mp-fixed-cubic-from-fifth-samples-raw(samples).map(point =>
        (point.at(0) * _mp-unit, point.at(1) * _mp-unit))
      let from = calc.clamp((clip-start - t0) / (t1 - t0), 0.0, 1.0)
      let to = calc.clamp((clip-finish - t0) / (t1 - t0), 0.0, 1.0)
      output += cubic-subdivide(cubic-subsegment(curve, from, to), int(step))
    }
  }
  if output.len() > 0 { output } else { none }
}

#let fixture = json("../build/m11-source-offset-curves.json")
#let source-ranges = ((1, 9, 15), (0, 0, 9), (0, 15, 24),
  (1, 0, 9), (1, 15, 24), (0, 9, 15))
#let source-paths = (upstream-m11-knot-paths.wa, upstream-m11-knot-paths.wb)
#let records = fixture.map(item => {
  let errors(candidate, expected) = {
    let values = ()
    let by-control = range(4).map(_ => ())
    for i in range(candidate.len()) {
      for j in range(4) {
        let error = _dist(candidate.at(i).at(j), expected.at(i).at(j))
        values.push(error)
        by-control.at(j).push(error)
      }
    }
    (mean: values.sum() / values.len(), max: calc.max(..values),
      control-max: by-control.map(errors => calc.max(..errors)))
  }
  let source-range = source-ranges.at(item.call)
  let source-path = source-paths.at(source-range.at(0))
  let source-times = range(source-path.len()).map(i => i / 16)
  let reconstructed = source-fragment-curves(source-path, source-times,
    source-range.at(1), source-range.at(2), 4)
  let recorded-center = item.curves.map(curve => curve.map(point =>
    (point.at(0), -point.at(1))))
  // `item.curves` are q0/currentPath cubics, using fixed-precision source
  // records when available. Compare them separately from the reconstructed
  // centerline input to isolate offset replay error.
  let recorded-positive = _mp-offset-boundary(recorded-center,
    item.offsets.map(value => -value))
  let recorded-negative = _mp-offset-boundary(recorded-center, item.offsets)
  let center-errors = errors(reconstructed, recorded-center)
  let positive = _mp-offset-boundary(reconstructed,
    item.offsets.map(value => -value))
  let negative = _mp-offset-boundary(reconstructed, item.offsets)
  let source-positive = item.positive.map(curve => curve.map(point =>
    (point.at(0), -point.at(1))))
  let source-negative = item.negative.map(curve => curve.map(point =>
    (point.at(0), -point.at(1))))
  let positive-errors = errors(positive, source-positive)
  let negative-errors = errors(negative, source-negative)
  let recorded-positive-errors = errors(recorded-positive, source-positive)
  let recorded-negative-errors = errors(recorded-negative, source-negative)
  let lane-errors = item.lanes.map(lane => {
    let fraction = lane.lane / lane.divisions
    let candidate = range(positive.len()).map(i => range(4).map(j =>
      _mp-fixed-mix-point(negative.at(i).at(j), positive.at(i).at(j), fraction)))
    let expected = lane.curves.map(curve => curve.map(point =>
      (point.at(0), -point.at(1))))
    let lane-error = errors(candidate, expected)
    (lane: lane.lane, mean: lane-error.mean, max: lane-error.max)
  })
  let recorded-lane-errors = item.lanes.map(lane => {
    let fraction = lane.lane / lane.divisions
    let candidate = range(recorded-positive.len()).map(i => range(4).map(j =>
      _mp-fixed-mix-point(recorded-negative.at(i).at(j),
        recorded-positive.at(i).at(j), fraction)))
    let expected = lane.curves.map(curve => curve.map(point =>
      (point.at(0), -point.at(1))))
    let lane-error = errors(candidate, expected)
    (lane: lane.lane, mean: lane-error.mean, max: lane-error.max)
  })
  (call: item.call,
    source-center-mean: center-errors.mean, source-center-max: center-errors.max,
    recorded-positive-mean: recorded-positive-errors.mean,
    recorded-positive-max: recorded-positive-errors.max,
    recorded-positive-control-max: recorded-positive-errors.control-max,
    recorded-negative-mean: recorded-negative-errors.mean,
    recorded-negative-max: recorded-negative-errors.max,
    recorded-negative-control-max: recorded-negative-errors.control-max,
    positive-mean: positive-errors.mean, positive-max: positive-errors.max,
    positive-control-max: positive-errors.control-max,
    negative-mean: negative-errors.mean, negative-max: negative-errors.max,
    negative-control-max: negative-errors.control-max,
    lanes: lane-errors, recorded-lanes: recorded-lane-errors)
})

#metadata(records) <m11-source-offset-check>
