// Row-level source-brush trace for the S104 hatch panel.
#import "../fiziko.typ": _add, _cos, _dist, _frame, _ink-loops, _metapost-rng-sequence, _mul, _path-fractions, _scanline-segments, _sin, _source-dash-length, _source-max-shading, _source-min-stroke, _mp-unit, _sub

#let panel = ((8, 8), (56, 13), (50, 36), (5, 31))
// Source P() flips the page's vertical axis. Its +30° MetaPost hatch
// therefore maps to -30° in the Typst page coordinates.
#let angle = -30
#let normal = (0, 0, -1)
#let light = (-0.353553, 0.382683, 0.853553)
#let segments = _scanline-segments(
  panel, angle, 3 * _source-max-shading, fit: true)
#let projections = panel.map(p => p.at(0) * _cos(angle) + p.at(1) * _sin(angle))
#let total-width = calc.max(..projections) - calc.min(..projections)
#let stream = _metapost-rng-sequence(1, calc.max(128, segments.len() * 128))
#let cursor = 0
#let rows = ()
#let draw-segments = segments.rev()
#let nn = calc.sqrt(normal.at(0) * normal.at(0) + normal.at(1) * normal.at(1) + normal.at(2) * normal.at(2))
#let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
#let shade = calc.pow(1 - calc.max(0.0,
  (normal.at(0) * light.at(0) + normal.at(1) * light.at(1) + normal.at(2) * light.at(2)) / (nn * ln)), 1.0)

#for segment in draw-segments {
  let subdivision-rng = cursor
  let subdivisions = 3 + int(calc.floor(stream.at(cursor) * 2 + 0.5))
  cursor += 1
  let row-fraction = segment.at(2) / calc.max(1, segment.at(3))
  let line-length = _dist(segment.at(0), segment.at(1))
  let width(t) = {
    let envelope = calc.sin(180deg * t) * line-length / total-width * calc.sin(180deg * row-fraction)
    2 * _source-min-stroke * (1 / 15 + shade) * (1 - 6 / 7 * calc.sqrt(calc.max(0.0, envelope)))
  }
  let points = range(subdivisions + 1).map(i => _add(segment.at(0),
    _mul(_sub(segment.at(1), segment.at(0)), i / subdivisions)))
  let frames = _frame(points, false)
  let fractions = _path-fractions(frames.map(e => e.at(0)), false)
  let widths = fractions.map(width)
  let ink = _ink-loops(frames, widths, false, _source-min-stroke,
    _source-dash-length, random-stream: stream, rng-offset: cursor,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-rng: true, with-stats: true, trace-nodes: true,
    source-rounding: true)
  rows.push((
    row: segment.at(2), length: line-length, subdivisions: subdivisions,
    width-min: calc.min(..widths), width-max: calc.max(..widths),
    outer: ink.at(2).outer, thin: ink.at(2).thin,
    dash-calls: ink.at(2).dashes, rng-start: cursor,
    rng-used: ink.at(1), nodes: ink.at(2).nodes,
  ))
  cursor += ink.at(1)
}

#metadata((rows: rows, rng-count: cursor, subdivision-draws: segments.len())) <s104-hatch-rows>
