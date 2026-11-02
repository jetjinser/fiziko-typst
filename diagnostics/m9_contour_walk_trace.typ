// Typst's first M9 contour and the 1 mm cells crossed by each path segment.
#import "../fiziko.typ": _woodblock-field, _wood-source-levels, _wood-source-width, _source-min-stroke, _source-dash-length, _metapost-rng-sequence, stroke-ink
#import "../contour.typ": marching-squares

#let model = _woodblock-field(33, 55, 1, source-res: 1)
#let sample-values = range(6).map(i => range(12).map(j =>
  (i, j + 12, (model.field)(i, j + 12))))
#let field = (x, y) => (model.field)(33 - y, x)
#let levels = _wood-source-levels(field, 55, 33, 55, 33, 1,
  model.rng-count)
#let first-contour-random = _metapost-rng-sequence(1,
  model.rng-count + 1).last()
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
#let brush-trace = stroke-ink(brush-path, width, closed: false,
  per: 0,
  min-w: _source-min-stroke, period: _source-dash-length,
  _source-rounding: true, _with-stats: true, _trace-nodes: true,
  _path-time: true)
#metadata((contour-count: paths.len(), level-count: levels.len(),
  field-range: (calc.min(..values), calc.max(..values)),
  sample-values: sample-values,
  target-values: ((6, 42, (model.field)(6, 42)),
    (0, 12, (model.field)(0, 12)), (0, 13, (model.field)(0, 13))),
  field-rng-count: model.rng-count,
  first-contour-random: first-contour-random,
  levels: levels, paths: paths,
  brush-rng-calls: brush-trace.at(1),
  brush-outer-leaves: brush-trace.at(2).outer,
  brush-thin-leaves: brush-trace.at(2).thin,
  brush-dashes: brush-trace.at(2).dashes,
  brush-widths: brush-trace.at(3).widths,
  brush-nodes: brush-trace.at(2).nodes))
<m9-contour-walk>
