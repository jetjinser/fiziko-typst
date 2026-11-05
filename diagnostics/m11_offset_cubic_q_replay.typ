// Test q recursion using pre-shadow lane cubics reconstructed by offsetPathGenerate.
#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _mp-unit, _source-dash-length, _source-min-stroke
#import "../build/m11-production-q-inputs.typ": m11-production-q-inputs
#import "m11_knot_lane_offset_cubics.typ": records

#let stream = _metapost-rng-sequence(1, 7000)
#let replay = m11-production-q-inputs.map(item => {
  let arc-record = records.find(record =>
    record.source-call == item.call and record.source-lane == item.lane)
  let arcs = if arc-record == none { item.source-arc-fixed }
    else { arc-record.quarter-arcs }
  let make-q(arcs) = range(item.segments).map(i => {
    let x0 = arcs.at(i)
    let x1 = arcs.at(i + 1)
    let y0 = item.source-width-fixed.at(i)
    let y1 = item.source-width-fixed.at(i + 1)
    let dx = x1 - x0
    let dy = y1 - y0
    ((x0, y0),
      (x0 + int(calc.round(dx / 3)), y0 + int(calc.round(dy / 3))),
      (x0 + int(calc.round(2 * dx / 3)), y0 + int(calc.round(2 * dy / 3))),
      (x1, y1))
  })
  let run(arcs) = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false,
    source-rounding: true, source-width-fixed: item.source-width-fixed,
    source-q-curves-fixed: make-q(arcs))
  let result = run(arcs)
  // Diagnostic oracle: substitute only source arc increments belonging to
  // the traced shadowCut connectors, then carry each correction downstream.
  let connector-indices = if item.call == 4 and item.lane == 2 { (22, 29) }
    else if item.call == 4 and item.lane == 6 { (1, 25, 30) }
    else if item.call == 5 and item.lane == 2 { (10, 17) }
    else { () }
  let connector-arcs = range(arcs.len()).map(j => {
    let correction = connector-indices.filter(i => i < j).map(i =>
      item.source-arc-fixed.at(i + 1) - item.source-arc-fixed.at(i)
        - (arcs.at(i + 1) - arcs.at(i)))
    arcs.at(j) + if correction.len() == 0 { 0 } else { correction.sum() }
  })
  let connector-result = run(connector-arcs)
  (call: item.call, lane: item.lane, source-calls: item.source-calls,
    q-nodes: result.at(2).nodes.filter(node => node.stage == "thin"),
    connector-q-nodes: connector-result.at(2).nodes
      .filter(node => node.stage == "thin"))
})

#metadata(replay) <m11-offset-cubic-q-replay>
