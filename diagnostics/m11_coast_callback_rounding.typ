// Compare float and candidate MetaPost 16.16 arithmetic at callback times
// that changed under exact fullcircle-point sampling.
#import "../fiziko.typ": _globe-land-outline-data, _mp-circle-point, _mp-rounded, _mp-scalar-rounded, _source-min-stroke, _mp-unit, _len, _cos, _sin
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let center = (19.0, 22.0)
#let diameter = 30.0
#let radius = diameter / 2
#let raw-light = (-0.353553, 0.382683, 0.853553)
#let light-length = calc.sqrt(raw-light.at(0) * raw-light.at(0)
  + raw-light.at(1) * raw-light.at(1) + raw-light.at(2) * raw-light.at(2))
#let light = raw-light.map(v => v / light-length)
#let fixed-light = light.map(_mp-scalar-rounded)

#let circle-param-at(map, time) = {
  let exact = range(map.len()).find(i => map.at(i).time == time)
  if exact != none { return map.at(exact).param }
  let segment = range(calc.max(0, map.len() - 1)).find(i =>
    map.at(i).arc == map.at(i + 1).arc
      and map.at(i).time < time and time < map.at(i + 1).time)
  if segment == none { return none }
  let a = map.at(segment)
  let b = map.at(segment + 1)
  let f = (time - a.time) / (b.time - a.time)
  a.param * (1 - f) + b.param * f
}

#let callback-width(point, fixed: false, terms: false, coefficients: false) = {
  let local = (point.at(0) - center.at(0), point.at(1) - center.at(1))
  let radial = if fixed {
    _mp-scalar-rounded(_len(local) / diameter)
  } else { calc.min(0.999999, _len(local) / diameter) }
  let angle = calc.atan2(local.at(0), -local.at(1)) / 1deg
  let angle = if fixed { _mp-scalar-rounded(angle) } else { angle }
  let normal = if fixed {
    (_mp-scalar-rounded(radial * _cos(angle)),
     _mp-scalar-rounded(radial * _sin(angle)),
     _mp-scalar-rounded(calc.sqrt(calc.max(0.0, 1 - radial * radial))))
  } else {
    (radial * _cos(angle), radial * _sin(angle),
     calc.sqrt(calc.max(0.0, 1 - radial * radial)))
  }
  let products = range(3).map(i => {
    let product = normal.at(i) * (if fixed { fixed-light } else { light }).at(i)
    if fixed { _mp-scalar-rounded(product) } else { product }
  })
  let lam = if fixed {
    _mp-scalar-rounded(_mp-scalar-rounded(products.at(0) + products.at(1)) + products.at(2))
  } else { products.sum() }
  let lightness = calc.clamp(1 - lam, 0.0, 1.0)
  let lightness = if fixed { _mp-scalar-rounded(lightness) } else { lightness }
  let one-third = if coefficients { _mp-scalar-rounded(1 / 3) } else { 1 / 3 }
  let two-thirds = if coefficients { _mp-scalar-rounded(2 / 3) } else { 2 / 3 }
  let width = if terms {
    let base = _mp-rounded(_source-min-stroke * two-thirds)
    let slope = _mp-rounded(_source-min-stroke * one-third)
    base + _mp-rounded(slope * lightness)
  } else { _source-min-stroke * (2 / 3 + lightness / 3) }
  let width = if coefficients and not terms {
    let factor = _mp-scalar-rounded(two-thirds + _mp-scalar-rounded(one-third * lightness))
    _mp-rounded(_source-min-stroke * factor)
  } else if fixed and not terms { _mp-rounded(width) } else { width }
  int(calc.round(width / _mp-unit * 65536))
}

#let cases = ((1, 136, 9796), (2, 58, 9885), (2, 59, 10673),
  (2, 63, 9007), (2, 103, 9007), (2, 107, 10673),
  (2, 108, 9885), (2, 109, 9071), (2, 167, 8822))
#let rows = cases.map(((mass, time, expected)) => {
  let data = _globe-land-outline-data(upstream-landmasses.at(mass - 1),
    (0, 0), radius, center)
  let param = circle-param-at(data.source-circle-time-map, time)
  let c = _mp-circle-point(param)
  let local = (2 * radius * c.at(0), -2 * radius * c.at(1))
  let point = (center.at(0) + local.at(0), center.at(1) + local.at(1))
  let fixed-local = (_mp-rounded(local.at(0)), _mp-rounded(local.at(1)))
  let fixed-point = (_mp-rounded(center.at(0) + fixed-local.at(0)),
    _mp-rounded(center.at(1) + fixed-local.at(1)))
  (landmass: mass, time: time, parameter: param, expected: expected,
   float: callback-width(point), fixed-point: callback-width(fixed-point),
   fixed-all: callback-width(fixed-point, fixed: true),
   fixed-terms: callback-width(fixed-point, fixed: true, terms: true),
   terms-only: callback-width(fixed-point, terms: true),
   fixed-coefficients: callback-width(fixed-point, fixed: true, coefficients: true),
   fixed-term-coefficients: callback-width(fixed-point, fixed: true,
     terms: true, coefficients: true))
})
#metadata(rows) <m11-coast-callback-rounding>
