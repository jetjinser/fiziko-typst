// Verify that translated shadow outlines can reuse their unshifted edge grid.
#import "../fiziko.typ": _path-polygon-crossings, _polygon-edge-grid

#let cases = (
  (name: "circle", polygon: range(128).map(i => (
    2.0 * calc.cos(i * 360deg / 128),
    1.4 * calc.sin(i * 360deg / 128),
  )), path: ((-3.0, 0.2), (3.0, 0.2)), shift: (0.75, -0.1)),
  (name: "concave", polygon: ((0.0, 0.0), (2.0, 0.0), (2.0, 1.0),
    (1.0, 0.4), (0.0, 1.0)), path: ((-1.0, 0.5), (3.0, 0.5)),
    shift: (-0.4, 0.25)),
)

#let results = cases.map(case => {
  let shifted = case.polygon.map(point => (
    point.at(0) + case.shift.at(0), point.at(1) + case.shift.at(1)))
  let direct = _path-polygon-crossings(case.path, shifted)
  let reused = _path-polygon-crossings(case.path, case.polygon,
    index: _polygon-edge-grid(case.polygon), shift: case.shift)
  (name: case.name, direct-count: direct.len(), reused-count: reused.len(),
    exact: direct == reused, direct: direct, reused: reused)
})
#assert(results.all(result => result.exact), message: "translated edge-grid crossings differ")
#assert(results.all(result => result.direct.all(event =>
  event.keys().contains("polygon-fraction")
  and event.at("polygon-fraction") >= -1e-6
  and event.at("polygon-fraction") <= 1 + 1e-6
  and calc.abs(event.at("polygon-segment-time")
    - event.at("polygon-edge") - event.at("polygon-fraction")) < 1e-9)),
  message: "crossings must retain their local shadow-edge parameter")
#metadata(results) <m11-shifted-shadow-index>
