// Typst's first M9 contour and the 1 mm cells crossed by each path segment.
#import "../fiziko.typ": _woodblock-field, _wood-source-levels
#import "../contour.typ": marching-squares

#let model = _woodblock-field(33, 55, 1, source-res: 1)
#let sample-values = range(6).map(i => range(12).map(j =>
  (i, j + 12, (model.field)(i, j + 12))))
#let field = (x, y) => (model.field)(33 - y, x)
#let levels = _wood-source-levels(field, 55, 33, 55, 33, 1,
  model.rng-count)
#let grid = range(34).map(j => range(56).map(i => field(i, j)))
#let values = grid.fold((), (all, row) => all + row)
#let result = marching-squares(field, 0, 0, 55, 33, levels: levels,
  nx: 55, ny: 33, with-count: true)
#let contours = result.at(0)
#let paths = contours.enumerate().map(((index, path)) => {
  let cells = ()
  for i in range(path.len() - 1) {
    let midpoint = ((path.at(i).at(0) + path.at(i + 1).at(0)) / 2,
      (path.at(i).at(1) + path.at(i + 1).at(1)) / 2)
    cells.push((int(calc.floor(midpoint.at(0))),
      int(calc.floor(midpoint.at(1)))))
  }
  (index: index, start: path.first(), end: path.last(), points: path, cells: cells)
})
#metadata((contour-count: contours.len(), level-count: result.at(1),
  field-range: (calc.min(..values), calc.max(..values)),
  sample-values: sample-values,
  levels: levels, paths: paths)) <m9-contour-walk>
