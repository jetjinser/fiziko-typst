#import "../fiziko.typ": _mp-fixed-cubic-arc-raw, _mp-fixed-cubic-from-quarter-samples-raw
#import "../build/m11-production-arc-fixture.typ": m11-production-arc-fixture

#let result = m11-production-arc-fixture.map(group => {
  let arcs = group.segments.map(segment => {
    let samples = segment.samples
    let quarters = (samples.at(0), samples.at(1), samples.at(3), samples.at(4))
    let controls = _mp-fixed-cubic-from-quarter-samples-raw(quarters)
    let cubic-arc = _mp-fixed-cubic-arc-raw(controls)
    let chord-arc = int(calc.round(range(4).map(i => {
      let a = samples.at(i)
      let b = samples.at(i + 1)
      calc.sqrt((b.at(0) - a.at(0)) * (b.at(0) - a.at(0))
        + (b.at(1) - a.at(1)) * (b.at(1) - a.at(1))) * 65536
    }).sum()))
    (cubic: cubic-arc, chord: chord-arc, expected: segment.expected)
  })
  (call: group.call, lane: group.lane,
    arcs: arcs.map(item => item.cubic),
    chord-arcs: arcs.map(item => item.chord),
    source-arcs: arcs.map(item => item.expected),
    cubic-mae: arcs.map(item => calc.abs(item.cubic - item.expected)).sum() / arcs.len(),
    cubic-max: calc.max(..arcs.map(item => calc.abs(item.cubic - item.expected))),
    chord-mae: arcs.map(item => calc.abs(item.chord - item.expected)).sum() / arcs.len(),
    chord-max: calc.max(..arcs.map(item => calc.abs(item.chord - item.expected))))
})
#metadata(result) <m11-production-arc-check>
