// Probe the M11 mass-4 integer path-time 43 callback at the source-mapped
// outline point, with alternative MetaPost fixed-point boundaries.
#import "../fiziko.typ": _globe-land-outline-data, _mp-circle-point, _mp-cubic-split, _mp-fixed-cubic-arc, _mp-rounded, _mp-scalar-rounded, _source-min-stroke, _mp-unit, _cos, _sin
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let center = (19.0, 22.0)
#let radius = 15.0
#let diameter = 30.0
#let len(v) = calc.sqrt(v.at(0) * v.at(0) + v.at(1) * v.at(1))
#let raw-light = (-0.353553, 0.382683, 0.853553)
#let light-length = calc.sqrt(raw-light.at(0) * raw-light.at(0)
  + raw-light.at(1) * raw-light.at(1) + raw-light.at(2) * raw-light.at(2))
#let light = raw-light.map(v => v / light-length)

#let data = _globe-land-outline-data(upstream-landmasses.at(3), (0, 0),
  radius, center)
#let source-time = 43.0
#let segment = range(data.source-times.len() - 1).find(i =>
  data.source-times.at(i) <= source-time
    and source-time <= data.source-times.at(i + 1))
#let fraction = (source-time - data.source-times.at(segment)) / (data.source-times.at(segment + 1) - data.source-times.at(segment))
#let point = (
  data.points.at(segment).at(0) * (1 - fraction)
    + data.points.at(segment + 1).at(0) * fraction,
  data.points.at(segment).at(1) * (1 - fraction)
    + data.points.at(segment + 1).at(1) * fraction,
)

#let width(point, fixed: false, terms: false) = {
  let local = (point.at(0) - center.at(0), point.at(1) - center.at(1))
  let radial = len(local) / diameter
  let angle = calc.atan2(local.at(0), -local.at(1)) / 1deg
  if fixed {
    radial = _mp-scalar-rounded(radial)
    angle = _mp-scalar-rounded(angle)
  }
  let normal = (
    radial * _cos(angle), radial * _sin(angle),
    calc.sqrt(calc.max(0.0, 1 - radial * radial)),
  )
  if fixed {
    normal = normal.map(v => _mp-scalar-rounded(v))
  }
  let products = range(3).map(i => {
    let product = normal.at(i) * (if fixed {
      _mp-scalar-rounded(light.at(i))
    } else { light.at(i) })
    if fixed { _mp-scalar-rounded(product) } else { product }
  })
  let lam = if fixed {
    _mp-scalar-rounded(_mp-scalar-rounded(products.at(0) + products.at(1))
      + products.at(2))
  } else { products.sum() }
  let shade = calc.clamp(1 - lam, 0.0, 1.0)
  if fixed { shade = _mp-scalar-rounded(shade) }
  let result = if terms {
    let base = _mp-rounded(_source-min-stroke * (2 / 3))
    let slope = _mp-rounded(_source-min-stroke * (1 / 3))
    base + _mp-rounded(slope * shade)
  } else { _source-min-stroke * (2 / 3 + shade / 3) }
  int(calc.round(result / _mp-unit * 65536))
}

#let fixed-point = point.map(_mp-rounded)
#let query-time = 49.0
#let outline-time-segment = range(data.source-times.len() - 1).find(i =>
  data.source-times.at(i) <= query-time
    and query-time <= data.source-times.at(i + 1))
#let outline-fraction = (
  (query-time - data.source-times.at(outline-time-segment))
    / (data.source-times.at(outline-time-segment + 1)
      - data.source-times.at(outline-time-segment)))
#let outline-point-at-time = (
  data.points.at(outline-time-segment).at(0) * (1 - outline-fraction)
    + data.points.at(outline-time-segment + 1).at(0) * outline-fraction,
  data.points.at(outline-time-segment).at(1) * (1 - outline-fraction)
    + data.points.at(outline-time-segment + 1).at(1) * outline-fraction,
)
#let circle-time-segment = range(data.source-circle-time-map.len() - 1).find(i => {
  let a = data.source-circle-time-map.at(i)
  let b = data.source-circle-time-map.at(i + 1)
  a.arc == b.arc and a.time <= query-time and query-time <= b.time
})
#let circle-a = data.source-circle-time-map.at(circle-time-segment)
#let circle-b = data.source-circle-time-map.at(circle-time-segment + 1)
#let circle-fraction = (query-time - circle-a.time) / (circle-b.time - circle-a.time)
#let circle-param = (
  circle-a.param * (1 - circle-fraction)
    + circle-b.param * circle-fraction)
#let circle-unit-point = _mp-circle-point(circle-param)
#let exact-circle-point = (
  center.at(0) + diameter * circle-unit-point.at(0),
  center.at(1) - diameter * circle-unit-point.at(1),
)
#let circle-cubic(segment) = {
  let a0 = segment * 45
  let a1 = (segment + 1) * 45
  let p0 = (0.5 * _cos(a0), 0.5 * _sin(a0))
  let p1 = (0.5 * _cos(a1), 0.5 * _sin(a1))
  let h = 0.1326082449
  let tangent(angle) = (-_sin(angle), _cos(angle))
  let c0 = (p0.at(0) + tangent(a0).at(0) * h,
    p0.at(1) + tangent(a0).at(1) * h)
  let c1 = (p1.at(0) - tangent(a1).at(0) * h,
    p1.at(1) - tangent(a1).at(1) * h)
  let world(point) = (center.at(0) - diameter * point.at(1),
    center.at(1) - diameter * point.at(0))
  (world(p0), world(c0), world(c1), world(p1))
}
#let first-curve = int(calc.floor(circle-a.param))
#let first-fraction = circle-a.param - first-curve
#let first-cubic-right = _mp-cubic-split(
  circle-cubic(first-curve), first-fraction).right
#let first-cubic-right-local = first-cubic-right.map(point => (
  (point.at(0) - center.at(0)) / (25.4 / 72),
  (center.at(1) - point.at(1)) / (25.4 / 72),
))
#let source-model-arc-48-49 = _mp-fixed-cubic-arc(
  first-cubic-right.map(point => point.map(axis => axis * 1mm)))
#let source-model-arc-48-49-mm = source-model-arc-48-49 / 65536 * _mp-unit
#let bp-mm = 25.4 / 72
#let source-local-cubic(controls) = controls.map(point => (
  (center.at(0) + point.at(0) * bp-mm) * 1mm,
  (center.at(1) - point.at(1) * bp-mm) * 1mm,
))
#let traced-cubic-48 = source-local-cubic((
  (-12.65675, -40.59203), (-8.59592, -41.85849),
  (-4.33202, -42.5196), (0, -42.5196)))
#let traced-cubic-49 = source-local-cubic((
  (0, -42.5196), (5.89757, -42.5196),
  (11.66862, -41.29402), (16.97319, -38.98431)))
#let traced-arc-48-49 = _mp-fixed-cubic-arc(traced-cubic-48) / 65536 * _mp-unit
#let traced-arc-49-50 = _mp-fixed-cubic-arc(traced-cubic-49) / 65536 * _mp-unit
#metadata((mass: 4, source-time: source-time, source-width-fixed: 10330,
  point: point, fixed-point: fixed-point,
  width-float: width(point),
  width-point-rounded: width(fixed-point),
  width-fixed: width(fixed-point, fixed: true),
  width-terms: width(fixed-point, fixed: true, terms: true),
  query-time: query-time, outline-point-at-time: outline-point-at-time,
  circle-map: (circle-a, circle-b), circle-param: circle-param,
  exact-circle-point: exact-circle-point,
  mapped-cubic-right-local: first-cubic-right-local,
  source-model-arc-48-49-mm: source-model-arc-48-49-mm,
  traced-arc-48-49-mm: traced-arc-48-49,
  traced-arc-49-50-mm: traced-arc-49-50,
  sampled-point-width: width(outline-point-at-time),
  exact-circle-point-width: width(exact-circle-point),
  exact-circle-fixed-width: width(exact-circle-point.map(_mp-rounded), fixed: true)))
  <m11-coast-path-time-width>
