// Row-level source-brush trace for the S104 hatch panel.
#import "../fiziko.typ": _add, _cos, _dist, _flat-surface-source-width, _frame, _ink-loops, _metapost-rng-sequence, _mp-fixed-cubic-at, _mp-fixed-cubic-arc-raw, _mp-fixed-pyth-distance, _mp-path-subdivision-times, _mp-rounded, _mp-scalar-rounded, _mul, _path-fractions, _scanline-segments, _sin, _source-dash-length, _source-max-shading, _source-min-stroke, _mp-unit, _sub

#let panel = ((8, 8), (56, 13), (50, 36), (5, 31))
// Source P() flips the page's vertical axis. Its +30° MetaPost hatch
// therefore maps to -30° in the Typst page coordinates.
#let angle = -30
#let use-source-fixed-scanlines = true
#let normal = (0, 0, -1)
#let light = (-0.353553, 0.382683, 0.853553)
#let segments = _scanline-segments(
  panel, angle, 3 * _source-max-shading, fit: true,
  source-fixed: use-source-fixed-scanlines)
#let projections = panel.map(p => p.at(0) * _cos(angle) + p.at(1) * _sin(angle))
#let total-width = if use-source-fixed-scanlines {
  segments.first().at(5)
} else { calc.max(..projections) - calc.min(..projections) }
#let stream = _metapost-rng-sequence(1, calc.max(128, segments.len() * 128))
#let cursor = 0
#let fixed-width-q-cursor = 0
#let rows = ()
#let draw-segments = segments.rev()
#let nn = calc.sqrt(normal.at(0) * normal.at(0) + normal.at(1) * normal.at(1) + normal.at(2) * normal.at(2))
#let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
#let shade = calc.pow(1 - calc.max(0.0,
  (normal.at(0) * light.at(0) + normal.at(1) * light.at(1) + normal.at(2) * light.at(2)) / (nn * ln)), 1.0)

#for segment in draw-segments {
  let subdivision-rng = cursor
  let requested-subdivisions = 3 + int(calc.floor(stream.at(cursor) * 2 + 0.5))
  cursor += 1
  let subdivision-times = _mp-path-subdivision-times(requested-subdivisions)
  let row-fraction = segment.at(2) / calc.max(1, segment.at(3))
  let fixed-width-q-subdivision-start = fixed-width-q-cursor
  let fixed-width-q-requested-subdivisions = 3 + int(calc.floor(
    stream.at(fixed-width-q-cursor) * 2 + 0.5))
  fixed-width-q-cursor += 1
  let fixed-width-q-subdivision-times = _mp-path-subdivision-times(
    fixed-width-q-requested-subdivisions)
  let fixed-width-q-points = fixed-width-q-subdivision-times.map(t =>
    _mp-fixed-cubic-at(segment.at(6), t).map(value =>
      value / 65536 * _mp-unit))
  let fixed-width-q-frames = _frame(fixed-width-q-points, false)
  let fixed-width-q-fractions = _path-fractions(
    fixed-width-q-frames.map(e => e.at(0)), false)
  let fixed-source-arc-positions = (0.0,)
  for i in range(fixed-width-q-points.len() - 1) {
    fixed-source-arc-positions.push(fixed-source-arc-positions.last()
      + _mp-fixed-pyth-distance(fixed-width-q-points.at(i),
        fixed-width-q-points.at(i + 1)))
  }
  let fixed-line-length = fixed-source-arc-positions.last()
  let points = subdivision-times.map(t => _mp-fixed-cubic-at(
    segment.at(6), t).map(value => value / 65536 * _mp-unit))
  let frames = _frame(points, false)
  let line-length = _dist(segment.at(0), segment.at(1))
  let width(t) = {
    let envelope = calc.sin(180deg * t) * line-length / total-width * calc.sin(180deg * row-fraction)
    2 * _source-min-stroke * (1 / 15 + shade) * (1 - 6 / 7 * calc.sqrt(calc.max(0.0, envelope)))
  }
  // Candidate MetaPost-style 16.16 arithmetic for the scalar envelope.
  // The height normal and light make surfLight exactly one in this fixture.
  let fixed-width(t) = _flat-surface-source-width(
    t, fixed-line-length, total-width, row-fraction, shade, 2)
  let q = _mp-scalar-rounded
  let width-ratio = q(fixed-line-length / total-width)
  let width-row = q(row-fraction)
  let width-sin-time = q(_sin(q(q(0.25) * 180)))
  let width-sin-row = q(_sin(q(width-row * 180)))
  let width-envelope = q(q(width-sin-time * width-ratio) * width-sin-row)
  let width-root = q(calc.sqrt(calc.max(0.0, width-envelope)))
  let width-fade = q(q(6 * width-root) / 7)
  let width-remain = q(1 - width-fade)
  let width-light = q(q(1 / 15) + q(shade))
  let width-base = q(2 * q(_source-min-stroke / _mp-unit))
  let width-bp = q(q(width-base * width-light) * width-remain)
  // A source-input-only callback probe for row 98, from S104-WIDTH-IN.
  let source-input-width = if segment.at(2) == 98 {
    _flat-surface-source-width(0.25,
      (94 + 179 / 256 + 52 / 65536) * _mp-unit,
      (150 + 181 / 256 + 229 / 65536) * _mp-unit,
      80 / 256 + 143 / 65536, shade, 2)
  } else { none }
  let fractions = _path-fractions(frames.map(e => e.at(0)), false)
  let widths = fractions.map(width)
  let source-arc-fixed = if segment.at(2) == 93 or segment.at(2) == 53 {
    let arcs = (0,)
    for i in range(fixed-width-q-frames.len() - 1) {
      let a = fixed-width-q-frames.at(i).at(0)
      let b = fixed-width-q-frames.at(i + 1).at(0)
      let p0 = (a.at(0) / _mp-unit, a.at(1) / _mp-unit)
      let p3 = (b.at(0) / _mp-unit, b.at(1) / _mp-unit)
      let p1 = (p0.at(0) + (p3.at(0) - p0.at(0)) / 3,
        p0.at(1) + (p3.at(1) - p0.at(1)) / 3)
      let p2 = (p0.at(0) + 2 * (p3.at(0) - p0.at(0)) / 3,
        p0.at(1) + 2 * (p3.at(1) - p0.at(1)) / 3)
      arcs.push(arcs.last() + _mp-fixed-cubic-arc-raw((p0, p1, p2, p3)))
    }
    arcs
  } else { () }
  let ink = _ink-loops(frames, widths, false, _source-min-stroke,
    _source-dash-length, random-stream: stream, rng-offset: cursor,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-rng: true, with-stats: true, trace-nodes: true,
    source-rounding: true)
  let arc-width-ink = if segment.at(2) == 93 {
    _ink-loops(frames, widths, false, _source-min-stroke,
      _source-dash-length, random-stream: stream, rng-offset: cursor,
      dash-extra: 0.01 * _mp-unit, dash-cap: 1,
      with-rng: true, with-stats: true, trace-nodes: true,
      source-rounding: true, width-by-arc: true)
  } else { none }
  // Exact 16.16 source q cubics captured from S104 row-93 outer node 278.
  // The four q segments map to this row's four sampled line segments.
  let source-q-curves-fixed = if segment.at(2) == 98 {
    // Source S104 y=-10.86390, complete outer q template (serial 183).
    // This oracle isolates row-98 recursion from production q construction.
    (
      (
        (0, 108 * 256 + 209),
        (2020 * 256 + 69, 89 * 256 + 224),
        (4040 * 256 + 139, 70 * 256 + 240),
        (6060 * 256 + 208, 51 * 256 + 255),
      ),
      (
        (6060 * 256 + 208, 51 * 256 + 255),
        (8081 * 256 + 21, 48 * 256 + 106),
        (10101 * 256 + 91, 44 * 256 + 212),
        (12121 * 256 + 160, 41 * 256 + 63),
      ),
      (
        (12121 * 256 + 160, 41 * 256 + 63),
        (14141 * 256 + 229, 44 * 256 + 212),
        (16162 * 256 + 43, 48 * 256 + 106),
        (18182 * 256 + 112, 51 * 256 + 255),
      ),
      (
        (18182 * 256 + 112, 51 * 256 + 255),
        (20202 * 256 + 181, 70 * 256 + 240),
        (22222 * 256 + 249, 89 * 256 + 224),
        (24243 * 256 + 62, 108 * 256 + 209),
      ),
    )
  } else if not use-source-fixed-scanlines and segment.at(2) == 54 {
    // Source S104 y=28.60222, root outer q template (source trace serial 967).
    (
      (
        (0, 108 * 256 + 209),
        (567251, 87 * 256 + 236),
        (1134501, 67 * 256 + 6),
        (1701752, 46 * 256 + 33),
      ),
      (
        (1701752, 46 * 256 + 33),
        (2269002, 42 * 256 + 45),
        (2836251, 38 * 256 + 56),
        (3403501, 34 * 256 + 68),
      ),
      (
        (3403501, 34 * 256 + 68),
        (3970752, 38 * 256 + 56),
        (4538002, 42 * 256 + 45),
        (5105253, 46 * 256 + 33),
      ),
      (
        (5105253, 46 * 256 + 33),
        (5672503, 67 * 256 + 6),
        (6239753, 87 * 256 + 236),
        (6807003, 108 * 256 + 209),
      ),
    )
  } else if not use-source-fixed-scanlines and segment.at(2) == 99 {
    // Source S104 y=-11.76086, root outer template (source trace serial 178).
    (
      (
        (0, 108 * 256 + 209),
        (1975 * 256 + 97, 90 * 256 + 58),
        (3950 * 256 + 195, 71 * 256 + 163),
        (5926 * 256 + 36, 53 * 256 + 12),
      ),
      (
        (5926 * 256 + 36, 53 * 256 + 12),
        (7901 * 256 + 134, 49 * 256 + 135),
        (9876 * 256 + 231, 46 * 256 + 3),
        (11852 * 256 + 73, 42 * 256 + 126),
      ),
      (
        (11852 * 256 + 73, 42 * 256 + 126),
        (13827 * 256 + 170, 46 * 256 + 3),
        (15803 * 256 + 12, 49 * 256 + 135),
        (17778 * 256 + 109, 53 * 256 + 12),
      ),
      (
        (17778 * 256 + 109, 53 * 256 + 12),
        (19753 * 256 + 206, 71 * 256 + 163),
        (21729 * 256 + 48, 90 * 256 + 58),
        (23704 * 256 + 145, 108 * 256 + 209),
      ),
    )
  } else if not use-source-fixed-scanlines and segment.at(2) == 93 {
    (
      (
        (0, 108 * 256 + 209),
        (2992 * 256 + 234, 86 * 256 + 1),
        (5985 * 256 + 212, 63 * 256 + 49),
        (8978 * 256 + 190, 40 * 256 + 97),
      ),
      (
        (8978 * 256 + 190, 40 * 256 + 97),
        (11971 * 256 + 167, 40 * 256 + 97),
        (14964 * 256 + 144, 40 * 256 + 96),
        (17957 * 256 + 121, 40 * 256 + 96),
      ),
      (
        (17957 * 256 + 121, 40 * 256 + 96),
        (20950 * 256 + 99, 63 * 256 + 4),
        (23943 * 256 + 77, 85 * 256 + 169),
        (26936 * 256 + 55, 108 * 256 + 77),
      ),
      (
        (26936 * 256 + 55, 108 * 256 + 77),
        (26936 * 256 + 90, 108 * 256 + 121),
        (26936 * 256 + 126, 108 * 256 + 165),
        (26936 * 256 + 161, 108 * 256 + 209),
      ),
    )
  } else { none }
  let source-q-ink = if source-q-curves-fixed == none { none } else {
    _ink-loops(frames, widths, false, _source-min-stroke,
      _source-dash-length, random-stream: stream, rng-offset: cursor,
      dash-extra: 0.01 * _mp-unit, dash-cap: 1,
      with-rng: true, with-stats: true, trace-nodes: true,
      source-rounding: true, source-q-curves-fixed: source-q-curves-fixed)
  }
  let typst-width-fixed = widths.map(width =>
    int(calc.round(width / _mp-unit * 65536)))
  let fixed-widths = fixed-width-q-fractions.map(fixed-width)
  let fixed-width-fixed = fixed-widths.map(width =>
    int(calc.round(width / _mp-unit * 65536)))
  let width-q-ink = _ink-loops(frames, widths, false, _source-min-stroke,
    _source-dash-length, random-stream: stream, rng-offset: cursor,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-rng: true, with-stats: true, trace-nodes: true,
    source-rounding: true, source-width-fixed: typst-width-fixed)
  let fixed-width-q-ink = _ink-loops(fixed-width-q-frames, fixed-widths, false, _source-min-stroke,
    _source-dash-length, random-stream: stream, rng-offset: fixed-width-q-cursor,
    dash-extra: 0.01 * _mp-unit, dash-cap: 1,
    with-rng: true, with-stats: true, trace-nodes: true,
    source-rounding: true, source-width-fixed: fixed-width-fixed,
    source-arc-positions: fixed-source-arc-positions)
  rows.push((
    row: segment.at(2), length: line-length,
    start: segment.at(0), end: segment.at(1),
    scanline-cubic-fixed: segment.at(6),
    intersection-hits: if segment.len() > 4 { segment.at(4) } else { () },
    requested-subdivisions: requested-subdivisions,
    subdivisions: subdivision-times.len() - 1,
    source-arc-fixed: if segment.at(2) == 93 or segment.at(2) == 53 { source-arc-fixed } else { () },
    width-min: calc.min(..widths), width-max: calc.max(..widths),
    sample-times: fractions, sample-widths: widths,
    fixed-width-q-times: fixed-width-q-subdivision-times,
    fixed-width-q-points: fixed-width-q-points,
    fixed-width-q-widths: fixed-width-q-subdivision-times.map(t =>
      int(calc.round(fixed-width(t) / _mp-unit * 65536))),
    source-input-width-fixed: if source-input-width == none { none } else {
      int(calc.round(source-input-width / _mp-unit * 65536))
    },
    fixed-width-q-scalar-trace: (
      ratio: int(calc.round(width-ratio * 65536)),
      sin-time: int(calc.round(width-sin-time * 65536)),
      sin-row: int(calc.round(width-sin-row * 65536)),
      envelope: int(calc.round(width-envelope * 65536)),
      root: int(calc.round(width-root * 65536)),
      fade: int(calc.round(width-fade * 65536)),
      remain: int(calc.round(width-remain * 65536)),
      light: int(calc.round(width-light * 65536)),
      base-bp: int(calc.round(width-base * 65536)),
      width-bp: int(calc.round(width-bp * 65536)),
    ),
    source-width-inputs: (line-length-mm: line-length,
      total-width-mm: total-width, row-fraction: row-fraction),
    outer: ink.at(2).outer, thin: ink.at(2).thin,
    dash-calls: ink.at(2).dashes, rng-start: cursor,
    rng-used: ink.at(1), nodes: ink.at(2).nodes,
    arc-width-nodes: if arc-width-ink == none { () } else { arc-width-ink.at(2).nodes },
    arc-width-calls: if arc-width-ink == none { none } else { arc-width-ink.at(1) },
    source-q-nodes: if source-q-ink == none { () } else { source-q-ink.at(2).nodes },
    source-q-calls: if source-q-ink == none { none } else { source-q-ink.at(1) },
    source-q-dashes: if source-q-ink == none { none } else { source-q-ink.at(2).dashes },
    width-q-nodes: if width-q-ink == none { () } else { width-q-ink.at(2).nodes },
    width-q-calls: if width-q-ink == none { none } else { width-q-ink.at(1) },
    width-q-dashes: if width-q-ink == none { none } else { width-q-ink.at(2).dashes },
    fixed-width-q-nodes: if fixed-width-q-ink == none { () } else { fixed-width-q-ink.at(2).nodes },
    fixed-width-q-calls: if fixed-width-q-ink == none { none } else { fixed-width-q-ink.at(1) },
    fixed-width-q-dashes: if fixed-width-q-ink == none { none } else { fixed-width-q-ink.at(2).dashes },
    fixed-width-q-rng-start: fixed-width-q-cursor,
    fixed-width-q-requested-subdivisions: fixed-width-q-requested-subdivisions,
    fixed-width-q-subdivisions: fixed-width-q-subdivision-times.len() - 1,
  ))
  cursor += ink.at(1)
  fixed-width-q-cursor += fixed-width-q-ink.at(1)
}

#metadata((rows: rows, rng-count: cursor, fixed-width-q-rng-count: fixed-width-q-cursor,
  subdivision-draws: segments.len())) <s104-hatch-rows>
