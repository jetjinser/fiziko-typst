// Typst's first M9 contour and the 1 mm cells crossed by each path segment.
#import "../fiziko.typ": _woodblock-field, _wood-source-levels, _wood-source-width, _source-width-q-curves, _source-min-stroke, _source-dash-length, _metapost-rng-sequence, _mp-scalar-rounded, _mp-unit, stroke-ink
#import "../contour.typ": marching-squares

#let model = _woodblock-field(33, 55, 1, source-res: 1)
#let sample-values = range(6).map(i => range(12).map(j =>
  (i, j + 12, (model.field)(i, j + 12))))
#let field = (x, y) => (model.field)(33 - y, x)
#let levels = _wood-source-levels(field, 55, 33, 55, 33, 1,
  model.rng-count)
#let first-contour-random = _metapost-rng-sequence(1,
  model.rng-count + 1).last()
#let maximum-column-random = _metapost-rng-sequence(1,
  model.rng-count - 34 + 6 + 1).last()
#let maximum-field-value = (model.field)(6, 42) / 24
#let maximum-field-offset = maximum-column-random / 192
#let maximum-wfield-terms = {
  let i = 6
  let j = 42
  let detail = _mp-scalar-rounded(1 / 5)
  let rho = _mp-scalar-rounded(1 / 24)
  let bd = 1.25 / 2 * detail
  let cumulative = 0.0
  let terms = ()
  for knot in model.knots {
    let dx = (i - knot.at(0)) * detail
    let dy = (j - knot.at(1)) * detail
    let r = calc.sqrt(dx * dx + dy * dy * calc.pow(calc.sin(60 * 1deg), 2))
    let a = calc.atan2(dx, dy)
    if r >= 2 * bd and 0.5 * r - bd < 8 {
      let q = 0.5 * r - bd
      let wave = ((calc.sqrt(calc.max(0.0, q)) / calc.pow(3.0, q))
        * (calc.sin(60 * 1deg) * 0.5 * calc.sin(-a) + 1)
        * (1 / 3 + 2 / 3 * calc.abs(calc.cos(a))))
      cumulative += wave * wave
    } else if r < 2 * bd {
      cumulative -= 10 * calc.sqrt(calc.max(0.0,
        1 - calc.pow(r / (2 * bd), 4)))
    }
    cumulative += calc.cos(2 * calc.pi / 30 * r * 1rad) / 64
    terms.push((r: r, angle: a, cumulative: cumulative))
  }
  let before-grid = cumulative
  let drift = i * rho / 5
  cumulative -= drift
  let grid-wave = calc.sin((calc.pi * i / 33 +
    4 * calc.pi * j / 55) * 1rad) / 32
  cumulative += grid-wave
  (terms: terms, before-grid: before-grid, drift: drift,
    grid-wave: grid-wave, final: cumulative)
}
#let grid = range(34).map(j => range(56).map(i => field(i, j)))
#let values = grid.fold((), (all, row) => all + row)
#let groups = levels.enumerate().map(((level-index, level)) => {
  let result = marching-squares(field, 0, 0, 55, 33, levels: (level,),
    nx: 55, ny: 33, with-count: true, source-walk: true)
  result.at(0).enumerate().map(((path-index, path)) => {
    (level-index: level-index, path-index: path-index, path: path)
  })
})
#let entries = groups.fold((), (all, group) => all + group)
#let paths = entries.enumerate().map(((index, entry)) => {
  let path = entry.path
  let cells = ()
  for i in range(path.len() - 1) {
    let midpoint = ((path.at(i).at(0) + path.at(i + 1).at(0)) / 2,
      (path.at(i).at(1) + path.at(i + 1).at(1)) / 2)
    cells.push((int(calc.floor(midpoint.at(0))),
      int(calc.floor(midpoint.at(1)))))
  }
  let cell-ranges = cells.map(cell => {
    let i = cell.at(0)
    let j = cell.at(1)
    let corners = (
      field(i, j), field(i + 1, j), field(i, j + 1), field(i + 1, j + 1),
    )
    (calc.max(..corners) - calc.min(..corners)) / 24
  })
  (index: index, level-index: entry.level-index,
    path-index: entry.path-index, start: path.first(), end: path.last(),
    points: path, cells: cells, cell-ranges: cell-ranges)
})
// Path zero is seeded by the first source cLine cell, with traversal order
// checked against the pinned MetaPost CLPATH/CLSTEP trace.
#let paired-path = paths.find(p => p.level-index == 0 and p.path-index == 0)
#let brush-path = paired-path.points.rev()
#let width = _wood-source-width(field, 55, 33, 55, 33, brush-path,
  source-time: true)
#let source-width-fixed = range(brush-path.len()).map(i =>
  int(calc.round(width(float(i) / (brush-path.len() - 1))
    / _mp-unit * 65536)))
#let brush-trace = stroke-ink(brush-path, width, closed: false,
  per: 0,
  min-w: _source-min-stroke, period: _source-dash-length,
  _source-rounding: true, _with-stats: true, _trace-nodes: true,
  _path-time: true, _source-width-fixed: source-width-fixed)
#let q-curves-fixed = _source-width-q-curves(paired-path.points, width)
#let q-trace = stroke-ink(brush-path, width, closed: false, per: 0,
  min-w: _source-min-stroke, period: _source-dash-length,
  _source-rounding: true, _with-stats: true, _trace-nodes: true,
  _path-time: true, _source-q-curves-fixed: q-curves-fixed)
#metadata((grid: (55, 33), contour-count: paths.len(), level-count: levels.len(),
  field-range: (calc.min(..values), calc.max(..values)),
  sample-values: sample-values,
  target-values: ((6, 42, (model.field)(6, 42)),
    (0, 12, (model.field)(0, 12)), (0, 13, (model.field)(0, 13))),
  maximum-components: (w-field: maximum-field-value - maximum-field-offset,
    field-offset: maximum-field-offset, field-value: maximum-field-value,
    column-random: maximum-column-random),
  maximum-wfield-terms: maximum-wfield-terms,
  field-rng-count: model.rng-count,
  first-contour-random: first-contour-random,
  levels: levels, paths: paths,
  brush-rng-calls: brush-trace.at(1),
  brush-outer-leaves: brush-trace.at(2).outer,
  brush-thin-leaves: brush-trace.at(2).thin,
  brush-dashes: brush-trace.at(2).dashes,
  brush-widths: brush-trace.at(3).widths,
  brush-nodes: brush-trace.at(2).nodes,
  q-rng-calls: q-trace.at(1),
  q-outer-leaves: q-trace.at(2).outer,
  q-thin-leaves: q-trace.at(2).thin,
  q-dashes: q-trace.at(2).dashes,
  q-nodes: q-trace.at(2).nodes))
<m9-contour-walk>
