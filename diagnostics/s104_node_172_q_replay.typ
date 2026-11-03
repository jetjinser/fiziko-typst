// Replay the pinned source's exact centerline and 16.16 width q cubics for
// S104 row -6.37912, thin node 172. This isolates q recursion from row setup.
#import "../fiziko.typ": _frame, _ink-loops, _source-dash-length, _source-min-stroke, _mp-unit

#let centerline = (
  (33.84724, 16.94310),
  (34.17966, 17.13503),
  (44.89505, 23.32155),
  (45.23093, 23.51546),
)
#let q-fixed = (
  (
    (8700 * 256 + 54, 42 * 256 + 128),
    (8793 * 256 + 14, 41 * 256 + 203),
    (8885 * 256 + 230, 41 * 256 + 22),
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
    (18051 * 256 + 73, 41 * 256 + 22),
    (18145 * 256 + 25, 41 * 256 + 204),
    (18238 * 256 + 233, 42 * 256 + 130),
  ),
)
#let trace = _ink-loops(
  _frame(centerline, false),
  centerline.map(_ => 0.16 * _mp-unit),
  false, _source-min-stroke, _source-dash-length,
  dash-extra: 0.01 * _mp-unit,
  with-stats: true, trace-nodes: true, source-rounding: true,
  source-q-curves-fixed: q-fixed,
)
#metadata((
  source-row: -6.37912,
  source-node: 172,
  source-cut-x-mm: 39.539,
  source-cut-q-time: 1.50017,
  typst-nodes: trace.at(2).nodes,
)) <s104-node-172-q-replay>
