// Compare MetaPost 16.16 woodBlock field operations at the source minimum.
#import "../fiziko.typ": _woodblock-field, _mp-rounded, _mp-scalar-rounded, _metapost-rng-raw-sequence

#let model = _woodblock-field(33, 55, 1, source-res: 1)
#let raw-rng-stream = _metapost-rng-raw-sequence(1, 4096)
#let source-knot-coordinate(raw, cells) = {
  let detail = _mp-scalar-rounded(1 / 5)
  let resolution = _mp-rounded(1)
  let radius = _mp-rounded(1.25)
  let radius-detail = _mp-rounded(radius * detail)
  let radius-detail-cells = _mp-scalar-rounded(radius-detail / resolution)
  let bound = _mp-scalar-rounded(
    _mp-scalar-rounded(cells * detail) + radius-detail-cells)
  let product = _mp-scalar-rounded(raw * bound)
  let half-radius = _mp-rounded(radius / 2)
  let half-radius-detail = _mp-rounded(half-radius * detail)
  let offset = _mp-scalar-rounded(half-radius-detail / resolution)
  let knot = _mp-scalar-rounded(product - offset)
  _mp-rounded(_mp-rounded(resolution * knot) / detail)
}
#let raw-rng-state = {
  let knots = ()
  let cursor = 0
  let rejected = 0
  while rejected < 10 and knots.len() < 45 and cursor + 1 < 4096 {
    let x = source-knot-coordinate(raw-rng-stream.at(cursor), 33)
    let y = source-knot-coordinate(raw-rng-stream.at(cursor + 1), 55)
    if knots.all(k => calc.sqrt(calc.pow(x - k.at(0), 2)
        + calc.pow(y - k.at(1), 2)) >= 20) {
      knots.push((x, y))
      cursor += 28
    } else { rejected += 1 }
    cursor += 2
  }
  (knots: knots, cursor: cursor)
}
#let raw-rng-knots = raw-rng-state.knots
#let s(x) = _mp-scalar-rounded(x)
#let mul(a, b) = s(a * b)
#let div(a, b) = s(a / b)
#let fixed-field(i, j, knots) = {
  let detail = s(1 / 5)
  let rho = s(1 / 24)
  let theta = s(calc.pi / 3)
  let sin-theta = s(calc.sin(theta * 1rad))
  let bd = mul(mul(div(1.25, 1), 1 / 2), detail)
  let cumulative = 0.0
  let terms = ()
  for knot in knots {
    let knot-x = div(mul(knot.at(0), detail), 1)
    let knot-y = div(mul(knot.at(1), detail), 1)
    let dx = s(mul(i, detail) - knot-x)
    let dy = s(mul(j, detail) - knot-y)
    let scaled-y = mul(dy, sin-theta)
    let r = s(calc.sqrt(s(mul(dx, dx) + mul(scaled-y, scaled-y))))
    let angle-deg = s(calc.atan2(dx, dy) / 1deg)
    let a = div(angle-deg, s(180 / calc.pi))
    if r >= mul(2, bd) and s(mul(1 / 2, r) - bd) < 8 {
      let q = s(mul(1 / 2, r) - bd)
      let radial = div(s(calc.sqrt(calc.max(0, q))), s(calc.pow(3, q)))
      let sin-a = s(calc.sin(-a * 1rad))
      let angular-a = s(mul(sin-theta, mul(1 / 2, sin-a)) + 1)
      let angular-b = s(1 / 3 + mul(2 / 3, calc.abs(s(calc.cos(a * 1rad)))) )
      let amplitude = mul(mul(radial, angular-a), angular-b)
      cumulative = s(cumulative + mul(amplitude, amplitude))
    } else if r < mul(2, bd) {
      let radial = div(r, mul(2, bd))
      let inside = s(1 - s(calc.pow(radial, 4)))
      cumulative = s(cumulative - mul(10, s(calc.sqrt(calc.max(0, inside)))))
    }
    let cos-angle = mul(mul(mul(2, calc.pi), 1 / 30), r)
    let ring = div(s(calc.cos(cos-angle * 1rad)), 64)
    cumulative = s(cumulative + ring)
    terms.push((r: r, angle: a, cumulative: cumulative))
  }
  let before-grid = cumulative
  let drift = div(mul(i, rho), 5)
  cumulative = s(cumulative - drift)
  let phase = s(div(mul(calc.pi, i), 33)
    + div(mul(mul(4, calc.pi), j), 55))
  let grid-wave = div(mul(1 / 32, s(calc.sin(phase * 1rad))), 1)
  cumulative = s(cumulative + grid-wave)
  (terms: terms, before-grid: before-grid, drift: drift,
    grid-wave: grid-wave, final: cumulative)
}

#metadata((targets: (
  min: (cell: (33, 29), source: -10.1679840088,
    float-knots: fixed-field(33, 29, model.knots),
    raw-rng-knots: fixed-field(33, 29, raw-rng-knots)),
  max: (cell: (6, 42), source: 0.2035675049,
    float-knots: fixed-field(6, 42, model.knots),
    raw-rng-knots: fixed-field(6, 42, raw-rng-knots))),
  raw-grid-samples: range(6).map(i => range(12).map(j => {
    let column-jitter = _mp-scalar-rounded(
      raw-rng-stream.at(raw-rng-state.cursor + i)
        * _mp-scalar-rounded(1 / 192))
    (i: i, j: j + 12, wfield: _mp-scalar-rounded(
      fixed-field(i, j + 12, raw-rng-knots).final + column-jitter))
  }))))
  <m9-fixed-field-probe>
