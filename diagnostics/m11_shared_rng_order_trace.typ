// Simulate complete production tube calls under current and source M11 draw order.
#import "../fiziko.typ": *
#import "../comparisons/m11-knot-paths.typ": upstream-m11-knot-paths

#let paths = (upstream-m11-knot-paths.wa, upstream-m11-knot-paths.wb)
#let times = paths.map(path => range(path.len()).map(i => i / upstream-m11-knot-paths.path-step))
#let intervals = ((0, 9), (9, 15), (15, 24))
#let current-order = ((0, 0), (0, 2), (1, 1), (0, 1), (1, 0), (1, 2))
#let source-order = ((1, 1), (0, 0), (0, 2), (1, 0), (1, 2), (0, 1))

#let run-order(order) = {
  let stream = _metapost-rng-sequence(1, 4639 + 16384)
  let cursor = 4639
  let rows = ()
  for (strand, segment) in order {
    let interval = intervals.at(segment)
    let path = _polyline-time-range(paths.at(strand), times.at(strand),
      interval.at(0), interval.at(1))
    let peer = if strand == 1 and segment == 0 { (0, 0) }
      else if strand == 1 and segment == 2 { (0, 2) }
      else if strand == 0 and segment == 1 { (1, 1) }
      else { none }
    let shadows = if peer == none { () } else {
      let peer-interval = intervals.at(peer.at(1))
      let peer-path = _polyline-time-range(paths.at(peer.at(0)),
        times.at(peer.at(0)), peer-interval.at(0), peer-interval.at(1))
      (_tube-shadow-plane(peer-path, 0.8, 1.2, source-cubic-step: 4),)
    }
    let result = tube(path, 0.8, hatch: "l", spacing: _source-spacing,
      w: _source-min-stroke, per: 0, min-w: _source-min-stroke,
      max-w: _source-max-shading, seed: 1, end-caps: false,
      rng: "metapost", source-cubic-step: 4, _radial-y-sign: 1,
      _shadow-planes: shadows, _random-stream: stream,
      _rng-offset: cursor, _with-rng: true)
    rows.push((strand: strand, segment: segment, calls: result.at(1) - cursor))
    cursor = result.at(1)
  }
  (calls: cursor - 4639, rows: rows)
}

#metadata((current-order: run-order(current-order),
  source-order: run-order(source-order))) <m11-shared-rng-order>
