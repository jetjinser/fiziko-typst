// Build source q templates from production lane samples plus traced callback
// widths and source shadowCut parameter splices.
#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _source-dash-length, _source-min-stroke, _mp-unit, _mp-fixed-cubic-from-quarter-samples-raw, _mp-fixed-cubic-from-fifth-samples-raw, _mp-fixed-cubic-arc-raw
#import "../build/m11-production-q-inputs.typ": m11-production-q-inputs

#let stream = _metapost-rng-sequence(1, 7000)
#let replay = m11-production-q-inputs.map(item => {
  let segment-arcs = range(item.segments).map(i => {
    let raw-samples = (0, 1, 3, 4).map(offset => {
      let point = item.points.at(i * 4 + offset)
      (point.at(0) / _mp-unit, point.at(1) / _mp-unit)
    })
    let cubic = _mp-fixed-cubic-from-quarter-samples-raw(raw-samples)
    _mp-fixed-cubic-arc-raw(cubic)
  })
  let arc-fixed = (0,)
  for length in segment-arcs { arc-fixed.push(arc-fixed.last() + length) }
  let fifth-segment-arcs = range(item.segments).map(i => {
    let raw-samples = range(5).map(offset => {
      let point = item.points.at(i * 4 + offset)
      (point.at(0) / _mp-unit, point.at(1) / _mp-unit)
    })
    let cubic = _mp-fixed-cubic-from-fifth-samples-raw(raw-samples)
    _mp-fixed-cubic-arc-raw(cubic)
  })
  let fifth-arc-fixed = (0,)
  for length in fifth-segment-arcs { fifth-arc-fixed.push(fifth-arc-fixed.last() + length) }
  let blended-arcs = range(arc-fixed.len()).map(i =>
    int(calc.round((arc-fixed.at(i) + fifth-arc-fixed.at(i)) / 2)))
  let generated-q-fixed = range(item.segments).map(i => {
    let x0 = arc-fixed.at(i)
    let x1 = arc-fixed.at(i + 1)
    let y0 = item.source-width-fixed.at(i)
    let y1 = item.source-width-fixed.at(i + 1)
    let p1 = (x0 + int(calc.round((x1 - x0) / 3)),
      y0 + int(calc.round((y1 - y0) / 3)))
    let p2 = (x0 + int(calc.round(2 * (x1 - x0) / 3)),
      y0 + int(calc.round(2 * (y1 - y0) / 3)))
    ((x0, y0), p1, p2, (x1, y1))
  })
  let q-from-arcs(arcs) = range(item.segments).map(i => {
    let x0 = arcs.at(i)
    let x1 = arcs.at(i + 1)
    let y0 = item.source-width-fixed.at(i)
    let y1 = item.source-width-fixed.at(i + 1)
    let p1 = (x0 + int(calc.round((x1 - x0) / 3)),
      y0 + int(calc.round((y1 - y0) / 3)))
    let p2 = (x0 + int(calc.round(2 * (x1 - x0) / 3)),
      y0 + int(calc.round(2 * (y1 - y0) / 3)))
    ((x0, y0), p1, p2, (x1, y1))
  })
  let run(q-fixed) = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false,
    source-rounding: true, source-width-fixed: item.source-width-fixed,
    source-q-curves-fixed: q-fixed)
  let generated-result = run(generated-q-fixed)
  let fifth-result = run(q-from-arcs(fifth-arc-fixed))
  let blended-result = run(q-from-arcs(blended-arcs))
  let source-result = run(q-from-arcs(item.source-arc-fixed))
  (call: item.call, lane: item.lane,
    source-calls: item.source-calls,
    typst-calls: generated-result.at(1), dashes: generated-result.at(2).dashes,
    q-nodes: generated-result.at(2).nodes.filter(node => node.stage == "thin"),
    fifth-arc-calls: fifth-result.at(1),
    fifth-arc-q-nodes: fifth-result.at(2).nodes.filter(node => node.stage == "thin"),
    blended-arc-calls: blended-result.at(1),
    blended-arc-q-nodes: blended-result.at(2).nodes.filter(node => node.stage == "thin"),
    source-arc-calls: source-result.at(1), source-arc-dashes: source-result.at(2).dashes,
    source-arc-q-nodes: source-result.at(2).nodes.filter(node => node.stage == "thin"),
    segment-arcs: segment-arcs, arc-fixed: arc-fixed)
})

#metadata(replay) <m11-production-q-replay>
