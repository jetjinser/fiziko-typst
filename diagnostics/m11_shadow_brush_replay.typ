// Feed source-traced post-shadow paths and callback widths into the Typst brush
// recursion. This isolates brush/tree behavior from lane and lightness fitting.
#import "../fiziko.typ": _frame, _ink-loops, _metapost-rng-sequence, _source-dash-length, _source-min-stroke, _mp-unit
#import "../build/m11-shadow-brush-inputs.typ": m11-shadow-inputs

#let stream = _metapost-rng-sequence(1, 7000)
#let replay = m11-shadow-inputs.map(item => {
  let result = _ink-loops(_frame(item.points, false), item.widths, false,
    _source-min-stroke, _source-dash-length,
    random-stream: stream, rng-offset: item.rng-offset,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-stats: true, source-rounding: true, trace-nodes: true,
    param-times: item.param-times, width-by-arc: false)
  (call: item.call, lane: item.lane,
    source-calls: item.source-calls,
    typst-calls: result.at(1), dashes: result.at(2).dashes,
    outer-nodes: result.at(2).nodes.filter(node => node.stage == "outer").len(),
    thin-nodes: result.at(2).nodes.filter(node => node.stage == "thin").len(),
    nodes: if ((item.call == 4 and (item.lane == 2 or item.lane == 6)) or
      (item.call == 5 and item.lane == 2)) { result.at(2).nodes } else { () })
})

#metadata(replay) <m11-shadow-brush-replay>
