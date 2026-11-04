// Compare the Typst offsetPathGenerate port against traced source q2/q3 cubics.
#import "../fiziko.typ": _dist, _mp-fixed-mix-point, _mp-offset-boundary

#let fixture = json("../build/m11-source-offset-curves.json")
#let records = fixture.map(item => {
  let positive = _mp-offset-boundary(item.curves, item.offsets)
  let negative = _mp-offset-boundary(item.curves,
    item.offsets.map(value => -value))
  let errors(candidate, expected) = {
    let values = ()
    for i in range(candidate.len()) {
      for j in range(4) {
        values.push(_dist(candidate.at(i).at(j), expected.at(i).at(j)))
      }
    }
    (mean: values.sum() / values.len(), max: calc.max(..values))
  }
  let positive-errors = errors(positive, item.positive)
  let negative-errors = errors(negative, item.negative)
  let lane-errors = item.lanes.map(lane => {
    let fraction = lane.lane / lane.divisions
    let candidate = range(positive.len()).map(i => range(4).map(j =>
      _mp-fixed-mix-point(negative.at(i).at(j), positive.at(i).at(j), fraction)))
    let lane-error = errors(candidate, lane.curves)
    (lane: lane.lane, mean: lane-error.mean, max: lane-error.max)
  })
  (call: item.call,
    positive-mean: positive-errors.mean, positive-max: positive-errors.max,
    negative-mean: negative-errors.mean, negative-max: negative-errors.max,
    lanes: lane-errors)
})

#metadata(records) <m11-source-offset-check>
