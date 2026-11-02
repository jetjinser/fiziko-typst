// Rebuild the M11 shadow q template from source callback widths and source
// arclength knots. This isolates `--` control construction from arc-length
// computation; source q control points themselves are not injected.
#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _source-dash-length, _source-min-stroke, _mp-unit
#import "../build/m11-shadow-brush-inputs.typ": m11-shadow-inputs

#let stream = _metapost-rng-sequence(1, 7000)
#let replay = m11-shadow-inputs.map(item => {
  let sample-step = int((item.widths.len() - 1) / item.source-path-segments)
  let source-width-fixed = range(item.source-path-segments + 1).map(i =>
    int(calc.round(item.widths.at(i * sample-step) / _mp-unit * 65536)))
  let source-q-fixed = range(item.source-path-segments).map(i => {
    let x0 = item.source-arc-fixed.at(i)
    let x1 = item.source-arc-fixed.at(i + 1)
    let y0 = source-width-fixed.at(i)
    let y1 = source-width-fixed.at(i + 1)
    let p1 = (
      x0 + int(calc.round((x1 - x0) / 3)),
      y0 + int(calc.round((y1 - y0) / 3)),
    )
    let p2 = (
      x0 + int(calc.round(2 * (x1 - x0) / 3)),
      y0 + int(calc.round(2 * (y1 - y0) / 3)),
    )
    ((x0, y0), p1, p2, (x1, y1))
  })
  let result = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false,
    source-rounding: true, source-width-fixed: source-width-fixed,
    source-q-curves-fixed: source-q-fixed)
  (call: item.call, lane: item.lane,
    source-calls: item.source-calls,
    typst-calls: result.at(1), dashes: result.at(2).dashes,
    q-calls: result.at(1), q-dashes: result.at(2).dashes,
    q-nodes: if ((item.call == 4 and (item.lane == 2 or item.lane == 6)) or
      (item.call == 5 and item.lane == 2)) {
        result.at(2).nodes.filter(node => node.stage == "thin")
      } else { () })
})

#metadata(replay) <m11-shadow-arc-replay>
