// Reconstruct pre-shadow M11 knot lanes from source-sampled centerline points
// using the production MetaPost offsetPathGenerate port.
#import "../fiziko.typ": _mp-cubic-split, _mp-fixed-cubic-arc-raw, _mp-fixed-cubic-from-fifth-samples-raw, _mp-fixed-cubic-from-quarter-samples-raw, _mp-offset-boundary, _mp-unit, _polyline-time-range, _source-path-time-splice, _tube-layout
#import "../comparisons/m11-knot-paths.typ": upstream-m11-knot-paths
#import "../build/m11-shadow-splice-cases.typ": m11-shadow-cases

#let paths = (upstream-m11-knot-paths.wa, upstream-m11-knot-paths.wb)
#let times = paths.map(path => range(path.len()).map(i => i / 16))
#let cases = ((4, 2, 0, 5, 0, 9), (4, 6, 0, 1, 0, 9),
  (5, 2, 2, 5, 15, 24))
#let records = cases.map(((source-call, source-lane, strand-segment,
    lane-index, start, finish)) => {
  let path = _polyline-time-range(paths.at(1), times.at(1), start, finish)
  let center-curves = range(int((path.len() - 1) / 4)).map(i => {
    let samples = range(5).map(j =>
      path.at(i * 4 + j).map(axis => axis / _mp-unit))
    let quarter = (samples.at(0), samples.at(1), samples.at(3), samples.at(4))
    (fifth: _mp-fixed-cubic-from-fifth-samples-raw(samples).map(point =>
        point.map(axis => axis * _mp-unit)),
      quarter: _mp-fixed-cubic-from-quarter-samples-raw(quarter).map(point =>
        point.map(axis => axis * _mp-unit)))
  })
  let layout = _tube-layout(path, 0.8, hatch: "l", closed: false, per: 0,
    source-cubic-step: 4, radial-y-sign: 1)
  let lane = layout.inner.at(lane-index)
  let piece = lane.pieces.first()
  let offsets = range(center-curves.len() + 1).map(_ => piece.u * 0.8)
  let fifth-lane-curves = _mp-offset-boundary(
    center-curves.map(curve => curve.fifth), offsets)
  let quarter-lane-curves = _mp-offset-boundary(
    center-curves.map(curve => curve.quarter), offsets)
  let shadow-case = m11-shadow-cases.find(record =>
    record.call == source-call and record.lane == source-lane)
  let post-shadow-segments(curves) = {
    let segments = range(curves.len()).map(i => (float(i), float(i + 1)))
    for splice in shadow-case.splices {
      segments = _source-path-time-splice(segments, splice.time)
    }
    segments
  }
  let subcurve(curve, start, finish) = {
    let prefix = if finish >= 1 - 1e-12 { curve }
      else { _mp-cubic-split(curve, finish).left }
    if start <= 1e-12 { prefix }
    else { _mp-cubic-split(prefix, start / finish).right }
  }
  let segment-arcs(curves, segments) = {
    let arcs = (0,)
    for (start, finish) in segments {
      let length = 0
      let time = start
      while time < finish - 1e-12 {
        let index = int(calc.min(calc.floor(time), curves.len() - 1))
        let end = calc.min(finish, index + 1)
        let local = subcurve(curves.at(index), time - index, end - index)
        length += _mp-fixed-cubic-arc-raw(local.map(point =>
          point.map(axis => axis / _mp-unit)))
        time = end
      }
      arcs.push(arcs.last() + length)
    }
    arcs
  }
  let quarter-post-segments = post-shadow-segments(quarter-lane-curves)
  let fifth-post-segments = post-shadow-segments(fifth-lane-curves)
  let quarter-arcs = segment-arcs(quarter-lane-curves, quarter-post-segments)
  let fifth-arcs = segment-arcs(fifth-lane-curves, fifth-post-segments)
  (source-call: source-call, source-lane: source-lane,
    strand-segment: strand-segment, typst-lane: lane-index, lane-u: piece.u,
    center-count: center-curves.len(), fifth-lane-curves: fifth-lane-curves,
    quarter-lane-curves: quarter-lane-curves,
    quarter-arcs: quarter-arcs, fifth-arcs: fifth-arcs)
})

#metadata(records) <m11-knot-lane-offset-cubics>
