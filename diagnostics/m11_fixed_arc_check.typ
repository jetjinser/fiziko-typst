#import "../fiziko.typ": _mp-fixed-cubic-arc-raw
#import "../build/m11-fixed-arc-fixture.typ": m11-fixed-arc-fixture

#let result = m11-fixed-arc-fixture.map(group => {
  let actual = group.segments.map(segment => _mp-fixed-cubic-arc-raw(segment.points))
  let expected = group.segments.map(segment => segment.expected)
  (call: group.call, lane: group.lane, count: actual.len(),
    arcs: actual,
    max-error: calc.max(..actual.zip(expected).map(pair => calc.abs(pair.at(0) - pair.at(1)))),
    exact: actual == expected)
})

#assert(result.all(item => item.exact), message: "MetaPost arc length mismatch")
#metadata(result) <m11-fixed-arc-check>
