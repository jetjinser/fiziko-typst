#import "../fiziko.typ": arc-pts, pt, _tube-layout, _ink-loops, _dist, _source-min-stroke, _source-dash-length, _source-max-shading

#let centerline = arc-pts(42, 205, 335, n: 40, center: (55, 68))
#let layout = _tube-layout(
  centerline,
  6,
  hatch: "l",
  spacing: 3 * _source-max-shading,
  per: 4,
  max-w: 0.308 * pt,
)
#let lane-traces = ()
#for (lane, item) in layout.inner.enumerate() {
  for piece in item.pieces {
    let lane-length = 0.0
    for i in range(piece.frames.len() - 1) {
      lane-length += _dist(piece.frames.at(i).at(0), piece.frames.at(i + 1).at(0))
    }
    let trace = _ink-loops(
      piece.frames,
      piece.widths,
      piece.closed,
      _source-min-stroke,
      _source-dash-length,
      trace-nodes: true,
      with-stats: true,
    )
    lane-traces.push((
      lane: lane + 1,
      path-length: lane-length,
      width-min: calc.min(..piece.widths),
      width-max: calc.max(..piece.widths),
      nodes: trace.at(2).nodes,
    ))
  }
}
#metadata(lane-traces) <m4-longitudinal-lane-traces>
