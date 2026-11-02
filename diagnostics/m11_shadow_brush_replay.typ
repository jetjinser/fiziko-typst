// Feed source-traced post-shadow paths and callback widths into the Typst brush
// recursion. This isolates brush/tree behavior from lane and lightness fitting.
#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _source-dash-length, _source-min-stroke, _mp-unit
#import "../build/m11-shadow-brush-inputs.typ": m11-shadow-inputs

#let stream = _metapost-rng-sequence(1, 7000)
#let replay = m11-shadow-inputs.map(item => {
  let sample-step = int((item.widths.len() - 1) / item.source-path-segments)
  let source-width-fixed = range(item.source-path-segments + 1).map(i =>
    int(calc.round(item.widths.at(i * sample-step) / _mp-unit * 65536)))
  let result = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, source-rounding: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false)
  let q-result = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, source-rounding: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false,
    source-width-fixed: source-width-fixed)
  (call: item.call, lane: item.lane,
    source-calls: item.source-calls,
    typst-calls: result.at(1), dashes: result.at(2).dashes,
    q-calls: q-result.at(1), q-dashes: q-result.at(2).dashes,
    q-nodes: if ((item.call == 4 and (item.lane == 2 or item.lane == 6)) or
      (item.call == 5 and item.lane == 2)) { q-result.at(2).nodes } else { () },
    outer-nodes: result.at(2).nodes.filter(node => node.stage == "outer").len(),
    thin-nodes: result.at(2).nodes.filter(node => node.stage == "thin").len(),
    nodes: if ((item.call == 4 and (item.lane == 2 or item.lane == 6)) or
      (item.call == 5 and item.lane == 2)) { result.at(2).nodes } else { () })
})

#metadata(replay) <m11-shadow-brush-replay>
