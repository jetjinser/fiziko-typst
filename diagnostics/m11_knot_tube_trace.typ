// Compare modeled M11 tube lane/brush calls for the source's six crossing intervals.
#import "../fiziko.typ": _add, _frame, _ink-loops, _mod, _mul, _polyline-time-range, _source-dash-length, _source-min-stroke, _source-max-shading, _source-spacing, _mp-unit, _tube-layout
#import "../comparisons/m11-knot-paths.typ": upstream-m11-knot-paths

#let paths = (upstream-m11-knot-paths.wa, upstream-m11-knot-paths.wb)
#let times = paths.map(path => range(path.len()).map(i => i / upstream-m11-knot-paths.path-step))
#let intervals = ((0, 9), (9, 15), (15, 24))
#let traces = ()
#let y-flipped-shade(layout, u, t) = {
  let nv = (layout.normal-at)(t)
  let slope = (layout.radius-slope)(t)
  let radial-z = calc.sqrt(calc.max(0.0, 1 - u * u))
  let tangent = (nv.at(1), nv.at(0))
  let norm = calc.max(1e-9, calc.sqrt(1 + slope * slope))
  let nx = (u * nv.at(0) - slope * tangent.at(0)) / norm
  let ny = (u * nv.at(1) - slope * tangent.at(1)) / norm
  let nz = radial-z / norm
  let lam = calc.clamp(nx * -0.353553 + ny * 0.382683 + nz * 0.853553,
    0.0, 1.0)
  calc.pow(1 - lam, 1.0)
}
#let y-flipped-widths(layout, u, times, widths) = times.enumerate().map(((i, t)) => {
  let current = (layout.shade)(u, t)
  if current > 1e-9 { widths.at(i) * y-flipped-shade(layout, u, t) / current }
  else { 0.0 }
})

#for strand in range(2) {
  for (segment, interval) in intervals.enumerate() {
    let path = _polyline-time-range(paths.at(strand), times.at(strand),
      interval.at(0), interval.at(1))
    let layout = _tube-layout(path, 0.8, hatch: "l", spacing: _source-spacing,
      coverage: auto, closed: false, per: 0, source-cubic-step: 4,
      w: _source-min-stroke,
      min-w: _source-min-stroke, max-w: _source-max-shading,
      radial-y-sign: 1)
    let calls = 0
    let dashes = 0
    let outer-nodes = 0
    let thin-nodes = 0
    let lane-count = 0
    let edge-calls = 0
    let candidate-edge-calls = 0
    let edge-dashes = 0
    let edge-lanes = ()
    let inner-lanes = ()
    for (section-index, section) in layout.division-sections.enumerate() {
      let knots = (section.from,)
      for t in layout.times {
        if t > section.from + 1e-8 and t < section.to - 1e-8 {
          knots.push(t)
        }
      }
      knots.push(section.to)
      for (side-index, side) in ((0, 1.0), (1, -1.0)) {
        let points = knots.map(t => _add((layout.center-at)(t),
          _mul((layout.normal-at)(t), side * (layout.rfun)(t))))
        let width(t) = {
          let residual = if side-index == 1 and _mod(section.divisions, 2) == 1 {
            calc.abs(2 * (layout.rfun)(t) / section.divisions
              - _source-spacing / 2) / _mp-unit
          } else { 1.0 }
          calc.min(_source-max-shading, _source-max-shading
            * (layout.shade)(side, t) * residual)
        }
        let lane-widths = knots.map(width)
        let result = _ink-loops(_frame(points, false),
          lane-widths, false, _source-min-stroke,
          _source-dash-length, seed: 1 + 500000 + section-index * 2 + side-index,
          dash-extra: 0.01 * _mp-unit, dash-cap: 1, with-stats: true,
          source-rounding: true, trace-nodes: true)
        edge-calls += result.at(1)
        edge-dashes += result.at(2).dashes
        let candidate-widths = y-flipped-widths(layout, side, knots, lane-widths)
        let candidate-result = _ink-loops(_frame(points, false),
          candidate-widths, false, _source-min-stroke,
          _source-dash-length, seed: 1 + 500000 + section-index * 2 + side-index,
          dash-extra: 0.01 * _mp-unit, dash-cap: 1, with-stats: true,
          source-rounding: true, trace-nodes: true)
        candidate-edge-calls += candidate-result.at(1)
        edge-lanes.push((section: section-index, side: side,
          start: points.first(), end: points.last(),
          points: points, widths: lane-widths,
          times: knots,
          normals: knots.map(t => (layout.normal-at)(t)),
          radius-slopes: knots.map(t => (layout.radius-slope)(t)),
          lightness: knots.map(t => (layout.shade)(side, t)),
          candidate-widths: candidate-widths,
          nodes: result.at(2).nodes,
          candidate-nodes: candidate-result.at(2).nodes,
          width-min: calc.min(..lane-widths), width-max: calc.max(..lane-widths),
          calls: result.at(1), candidate-calls: candidate-result.at(1)))
      }
    }
    let candidate-calls = 0
    for (lane-index, lane) in layout.inner.enumerate() {
      for (piece-index, piece) in lane.pieces.enumerate() {
        let dense-points = ()
        for time-index in range(piece.times.len() - 1) {
          let start-time = piece.times.at(time-index)
          let finish-time = piece.times.at(time-index + 1)
          for subdivision in range(16) {
            let time = start-time + (finish-time - start-time) * subdivision / 16
            dense-points.push(_add((layout.center-at)(time),
              _mul((layout.normal-at)(time), piece.u * (layout.rfun)(time))))
          }
        }
        dense-points.push(piece.frames.last().at(0))
        lane-count += 1
        let result = _ink-loops(piece.frames, piece.widths, piece.closed,
          _source-min-stroke, _source-dash-length, seed: 1 + piece.seed-offset,
          dash-extra: 0.01 * _mp-unit, dash-cap: 1, with-stats: true,
          source-rounding: true,
          trace-nodes: (lane-index == 1 or lane-index == 5)
            and piece-index == 0)
        calls += result.at(1)
        dashes += result.at(2).dashes
        let candidate-widths = y-flipped-widths(layout, piece.u, piece.times, piece.widths)
        let candidate-result = _ink-loops(piece.frames, candidate-widths,
          piece.closed, _source-min-stroke, _source-dash-length,
          seed: 1 + piece.seed-offset, dash-extra: 0.01 * _mp-unit,
          dash-cap: 1, with-stats: true, source-rounding: true,
          trace-nodes: (lane-index == 1 or lane-index == 5)
            and piece-index == 0)
        candidate-calls += candidate-result.at(1)
        inner-lanes.push((lane: lane-index, piece: piece-index,
          u: piece.u,
          start: piece.frames.first().at(0), end: piece.frames.last().at(0),
          points: piece.frames.map(frame => frame.at(0)), widths: piece.widths,
          times: piece.times, dense-points: dense-points,
          normals: piece.times.map(t => (layout.normal-at)(t)),
          radius-slopes: piece.times.map(t => (layout.radius-slope)(t)),
          lightness: piece.times.map(t => (layout.shade)(piece.u, t)),
          candidate-calls: candidate-result.at(1),
          nodes: if (lane-index == 1 or lane-index == 5) and piece-index == 0 {
            result.at(2).nodes
          } else { () },
          candidate-nodes: if (lane-index == 1 or lane-index == 5)
            and piece-index == 0 { candidate-result.at(2).nodes } else { () },
          width-min: calc.min(..piece.widths), width-max: calc.max(..piece.widths),
          calls: result.at(1), dashes: result.at(2).dashes))
        outer-nodes += result.at(2).nodes.filter(node => node.stage == "outer").len()
        thin-nodes += result.at(2).nodes.filter(node => node.stage == "thin").len()
      }
    }
    traces.push((strand: strand, segment: segment, start: interval.at(0),
      finish: interval.at(1), path-start: path.first(), path-end: path.last(),
      divisions: layout.inner-n + 1,
      lanes: lane-count, random-calls: calls, dash-patterns: dashes,
      edge-random-calls: edge-calls, edge-dash-patterns: edge-dashes,
      candidate-random-calls: candidate-calls,
      candidate-edge-random-calls: candidate-edge-calls,
      edge-lanes: edge-lanes, inner-lanes: inner-lanes, outer-nodes: outer-nodes,
      thin-nodes: thin-nodes, silhouette: layout.silhouette))
  }
}

#metadata(traces) <m11-knot-tube-trace>
