// Probe the M11 mass-4 integer path-time 43 callback at the source-mapped
// outline point, with alternative MetaPost fixed-point boundaries.
#import "../fiziko.typ": _globe-land-outline-data, _mp-rounded, _mp-scalar-rounded, _source-min-stroke, _mp-unit, _cos, _sin
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

#let width(point, fixed: false) = {
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
  let result = _source-min-stroke * (2 / 3 + shade / 3)
  int(calc.round(result / _mp-unit * 65536))
}

#let fixed-point = point.map(_mp-rounded)
#metadata((mass: 4, source-time: source-time, source-width-fixed: 10330,
  point: point, fixed-point: fixed-point,
  width-float: width(point),
  width-point-rounded: width(fixed-point),
  width-fixed: width(fixed-point, fixed: true)))
  <m11-coast-path-time-width>
