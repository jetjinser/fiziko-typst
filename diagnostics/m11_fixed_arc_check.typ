#import "../fiziko.typ": _mp-fixed-cubic-arc-raw, _mp-fixed-cubic-from-quarter-samples-raw
#import "../build/m11-fixed-arc-fixture.typ": m11-fixed-arc-fixture

#let result = m11-fixed-arc-fixture.map(group => {
  let actual = group.segments.map(segment => _mp-fixed-cubic-arc-raw(segment.points))
  let reconstructed = group.segments.map(segment => {
    let controls = _mp-fixed-cubic-from-quarter-samples-raw(segment.quarter-samples)
    _mp-fixed-cubic-arc-raw(controls)
  })
  let expected = group.segments.map(segment => segment.expected)
  (call: group.call, lane: group.lane, count: actual.len(),
    arcs: actual,
    reconstructed-arcs: reconstructed,
    reconstructed-max-error: calc.max(..reconstructed.zip(expected).map(pair =>
      calc.abs(pair.at(0) - pair.at(1)))),
    max-error: calc.max(..actual.zip(expected).map(pair => calc.abs(pair.at(0) - pair.at(1)))),
    exact: actual == expected)
})

#assert(result.all(item => item.exact), message: "MetaPost arc length mismatch")
#assert(result.all(item => item.reconstructed-max-error <= 2),
  message: "quarter-sample reconstructed arc exceeded 2 fixed units")
#metadata(result) <m11-fixed-arc-check>
