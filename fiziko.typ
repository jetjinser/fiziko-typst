/// fiziko.typ — MetaPost-style programmatic drawing for Typst.
///
/// A Typst port of the ideas in jemmybutton/fiziko (a MetaPost library for
/// black-and-white physics textbook illustrations):
///   * curves at varying distance (offsetPath)
///   * variable-width strokes ("brush"), with ink conservation: lines thinner
///     than the printable minimum become dashes carrying the same amount of ink
///   * hatched spheres ("spheres as concentric rings shaded by a light model")
///   * tubes with longitudinal hatching
///
/// Coordinate system: plain float pairs (x, y) in millimetres, y pointing down.
/// Every primitive returns content whose drawing origin (0, 0) is at the
/// placement point, so primitives compose with `+` inside a `canvas` box.
///
/// Usage:
///   #import "fiziko.typ": *
///   #canvas(110, 60,
///     stroke-ink(pts, t => 2 * pt * calc.sin(180 * t), closed: false)
///     + tag($m$, (50, 30))
///   )

#import "solve.typ": solve-linear, line-intersect, pyth-add, pyth-sub
#import "contour.typ": marching-squares
#import "intersection.typ": intersection-times

// ---------------------------------------------------------------------------
// constants
// ---------------------------------------------------------------------------
#let pt = 0.3514598          // one TeX point in millimetres
#let _mp-unit = 25.4 / 72    // MetaPost's unit scalar is one PostScript bp
#let min-width = 0.3 * pt    // thinnest printable line (mm); below this we dash
#let dash-min-length = 6 * min-width // MetaPost thinBrushPattern minimum (mm)
#let _source-min-stroke = 0.2 * pt
#let _source-brush-width-guard = _mp-unit / 100
#let _source-brush-time-guard = 1 / 100
#let _source-thin-brush-depth = 15
#let _source-tube-width-guard = _mp-unit / 1000
#let _source-horizon-crossing-depth = 5
#let _source-max-shading = 1.5 * _source-min-stroke
#let _source-spacing = 3 * _source-max-shading
#let _source-dash-length = 6 * _source-min-stroke
#let _source-dash-width-step = (_source-min-stroke - _source-min-stroke / 3) / 16
#let _source-stipple-size = 1.5 * _source-min-stroke
#let _source-min-stipple-step = 0.5 * _source-stipple-size
#let _source-stipple-spacing = 3 * _source-min-stipple-step
#let _source-stipple-spacing-ratio = 1.5
#let _source-min-stipple-width = _source-stipple-size / 20
#let _source-min-stipple-width-ratio = 1 / 20
#let _source-wood-block-detail = 1 / 5
#let _source-wood-block-res = 1 / 3
#let _source-wood-y-density = 1 / 24
#let _source-wood-knot-angle = 60
#let _source-wood-knot-radius = 1.25
#let _source-wood-knot-density = 20
// MetaPost stores both dimensional (bp) and dimensionless values as 16.16.
// Use distinct quantizers because lengths in mm and scalar ratios have
// different scaled units.
#let _mp-rounded(x) = calc.round(x / _mp-unit * 65536) / 65536 * _mp-unit
#let _mp-scalar-rounded(x) = calc.round(x * 65536) / 65536
#let _mp-fixed-mix(a, b, t) = {
  let q = _mp-scalar-rounded(t)
  // MetaPost's set_number_from_of_the_way evaluates B - (B - C) * t.
  // Reordering this as A + (C - A) * t is algebraically equivalent but can
  // differ by one 16.16 unit at each de Casteljau interpolation.
  let delta = _mp-rounded(a - b)
  _mp-rounded(a - _mp-rounded(delta * q))
}
#let _mp-fixed-mix-point(a, b, t) = (
  _mp-fixed-mix(a.at(0), b.at(0), t),
  _mp-fixed-mix(a.at(1), b.at(1), t),
)
#let _mp-fixed-half-trunc(x) = {
  if x < 0 { -calc.floor(-x / 2) } else { calc.floor(x / 2) }
}
#let _mp-fraction-one = 268435456
#let _mp-fixed-round-ratio(a, b) = {
  assert(b != 0, message: "fixed-point ratio denominator cannot be zero")
  let sign = if (a < 0) != (b < 0) { -1 } else { 1 }
  sign * calc.floor((calc.abs(a) + calc.abs(b) / 2) / calc.abs(b))
}
#let _mp-fixed-pyth-add(x, y) = {
  let a = calc.abs(x)
  let b = calc.abs(y)
  if a < b { let t = a; a = b; b = t }
  if b == 0 { return a }
  let big = a >= 2 * _mp-fraction-one
  if big { a = calc.floor(a / 4); b = calc.floor(b / 4) }
  while true {
    let ratio = _mp-fixed-round-ratio(b * _mp-fraction-one, a)
    let ratio = _mp-fixed-round-ratio(ratio * ratio, _mp-fraction-one)
    if ratio == 0 { break }
    let ratio = _mp-fixed-round-ratio(ratio * _mp-fraction-one,
      4 * _mp-fraction-one + ratio)
    a += _mp-fixed-round-ratio((a + a) * ratio, _mp-fraction-one)
    b = _mp-fixed-round-ratio(b * ratio, _mp-fraction-one)
  }
  if big { a * 4 } else { a }
}
#let _mp-fixed-pyth-distance(a, b) = {
  let dx = int(calc.round((b.at(0) - a.at(0)) / _mp-unit * 65536))
  let dy = int(calc.round((b.at(1) - a.at(1)) / _mp-unit * 65536))
  _mp-fixed-pyth-add(dx, dy) * _mp-unit / 65536
}
#let _mp-fixed-line-cubic(a, b) = {
  let delta = (b.at(0) - a.at(0), b.at(1) - a.at(1))
  let c1 = delta.map(value => _mp-fixed-round-ratio(value, 3))
  let c2 = delta.map(value => _mp-fixed-round-ratio(2 * value, 3))
  (a, (a.at(0) + c1.at(0), a.at(1) + c1.at(1)),
   (a.at(0) + c2.at(0), a.at(1) + c2.at(1)), b)
}
#let _mp-fixed-cubic-at(points, t) = {
  let q = int(calc.round(t * 65536))
  let mix(a, b) = (
    a.at(0) + _mp-fixed-round-ratio((b.at(0) - a.at(0)) * q, 65536),
    a.at(1) + _mp-fixed-round-ratio((b.at(1) - a.at(1)) * q, 65536),
  )
  let a = mix(points.at(0), points.at(1))
  let b = mix(points.at(1), points.at(2))
  let c = mix(points.at(2), points.at(3))
  let d = mix(a, b)
  let e = mix(b, c)
  mix(d, e)
}
#let _mp-fixed-arc-test(d0, d1, d2, v0: none, v02: none, v2: none,
                        // Inputs are raw 16.16 bp coordinates; MetaPost's
                        // arc_tol_k of 1/4096 bp is therefore 16 fixed units.
                        tolerance: 65536 / 4096, depth: 0) = {
  assert(depth <= 40, message: "MetaPost arc subdivision exceeded 40 levels")
  let v0 = if v0 == none { _mp-fixed-pyth-add(d0.at(0), d0.at(1)) } else { v0 }
  let v2 = if v2 == none { _mp-fixed-pyth-add(d2.at(0), d2.at(1)) } else { v2 }
  let dx01 = ( _mp-fixed-half-trunc(d0.at(0) + d1.at(0)),
                _mp-fixed-half-trunc(d0.at(1) + d1.at(1)) )
  let dx12 = ( _mp-fixed-half-trunc(d1.at(0) + d2.at(0)),
                _mp-fixed-half-trunc(d1.at(1) + d2.at(1)) )
  let dx02 = ( _mp-fixed-half-trunc(dx01.at(0) + dx12.at(0)),
                _mp-fixed-half-trunc(dx01.at(1) + dx12.at(1)) )
  let v002 = _mp-fixed-pyth-add(
    _mp-fixed-half-trunc(d0.at(0) + dx02.at(0)) + dx01.at(0),
    _mp-fixed-half-trunc(d0.at(1) + dx02.at(1)) + dx01.at(1))
  let v022 = _mp-fixed-pyth-add(
    _mp-fixed-half-trunc(dx02.at(0) + d2.at(0)) + dx12.at(0),
    _mp-fixed-half-trunc(dx02.at(1) + d2.at(1)) + dx12.at(1))
  let v02 = if v02 == none {
    _mp-fixed-pyth-add(
      _mp-fixed-half-trunc(d0.at(0) + d2.at(0)) + d1.at(0),
      _mp-fixed-half-trunc(d0.at(1) + d2.at(1)) + d1.at(1))
  } else { v02 }
  let tmp = calc.floor((v02 + 2) / 2)
  let arc1 = _mp-fixed-half-trunc(calc.floor((v0 + tmp) / 2) - v002) + v002
  let arc2 = _mp-fixed-half-trunc(calc.floor((v2 + tmp) / 2) - v022) + v022
  let arc = arc1 + arc2
  let xsimple = ((d0.at(0) >= 0 and d1.at(0) >= 0 and d2.at(0) >= 0) or (d0.at(0) <= 0 and d1.at(0) <= 0 and d2.at(0) <= 0))
  let ysimple = ((d0.at(1) >= 0 and d1.at(1) >= 0 and d2.at(1) >= 0) or (d0.at(1) <= 0 and d1.at(1) <= 0 and d2.at(1) <= 0))
  let simple = xsimple and ysimple
  let direct = ((d0.at(0) >= d0.at(1) and d1.at(0) >= d1.at(1) and d2.at(0) >= d2.at(1)) or (d0.at(0) <= d0.at(1) and d1.at(0) <= d1.at(1) and d2.at(0) <= d2.at(1)))
  if not simple and direct {
    let nx = (-d0.at(0), -d1.at(0), -d2.at(0))
    let swap-simple = ((nx.at(0) >= d0.at(1) and nx.at(1) >= d1.at(1) and nx.at(2) >= d2.at(1)) or (nx.at(0) <= d0.at(1) and nx.at(1) <= d1.at(1) and nx.at(2) <= d2.at(1)))
    simple = swap-simple
  }
  let discrepancy = calc.abs(arc - calc.floor((v0 + v2) / 2) - v02)
  if simple and discrepancy <= tolerance { return arc }
  let next-tolerance = tolerance + calc.floor(tolerance / 2)
  let half-v02 = calc.floor(v02 / 2)
  let left = _mp-fixed-arc-test(d0, dx01, dx02, v0: v0, v02: v002,
    v2: half-v02, tolerance: next-tolerance, depth: depth + 1)
  let right = _mp-fixed-arc-test(dx02, dx12, d2, v0: half-v02,
    v02: v022, v2: v2, tolerance: next-tolerance, depth: depth + 1)
  _mp-fixed-half-trunc(right - left) + left
}
#let _mp-fixed-cubic-arc-raw(points) = {
  let p = points.map(point => point.map(axis => calc.round(axis * 65536)))
  let d0 = (p.at(1).at(0) - p.at(0).at(0), p.at(1).at(1) - p.at(0).at(1))
  let d1 = (p.at(2).at(0) - p.at(1).at(0), p.at(2).at(1) - p.at(1).at(1))
  let d2 = (p.at(3).at(0) - p.at(2).at(0), p.at(3).at(1) - p.at(2).at(1))
  _mp-fixed-arc-test(d0, d1, d2)
}
#let _mp-fixed-cubic-from-quarter-samples-raw(samples) = {
  let p0 = samples.at(0)
  let p25 = samples.at(1)
  let p75 = samples.at(2)
  let p3 = samples.at(3)
  let a = (64 * p25.at(0) - 27 * p0.at(0) - p3.at(0),
           64 * p25.at(1) - 27 * p0.at(1) - p3.at(1))
  let b = (64 * p75.at(0) - p0.at(0) - 27 * p3.at(0),
           64 * p75.at(1) - p0.at(1) - 27 * p3.at(1))
  let p1 = ((3 * a.at(0) - b.at(0)) / 72,
            (3 * a.at(1) - b.at(1)) / 72)
  let p2 = ((-a.at(0) + 3 * b.at(0)) / 72,
            (-a.at(1) + 3 * b.at(1)) / 72)
  (p0, p1, p2, p3)
}
#let _mp-fixed-cubic-from-fifth-samples-raw(samples) = {
  assert(samples.len() == 5, message: "fifth-sample cubic fit needs five points")
  let p = samples.map(point => point.map(axis => calc.round(axis * 65536)))
  let p0 = p.at(0)
  let p25 = p.at(1)
  let p50 = p.at(2)
  let p75 = p.at(3)
  let p3 = p.at(4)
  let solve(axis) = {
    let r25 = 64 * p25.at(axis) - 27 * p0.at(axis) - p3.at(axis)
    let r50 = 64 * p50.at(axis) - 8 * p0.at(axis) - 8 * p3.at(axis)
    let r75 = 64 * p75.at(axis) - p0.at(axis) - 27 * p3.at(axis)
    let b1 = 27 * r25 + 24 * r50 + 9 * r75
    let b2 = 9 * r25 + 24 * r50 + 27 * r75
    let p1 = _mp-fixed-round-ratio(1386 * b1 - 1062 * b2, 793152)
    let p2 = _mp-fixed-round-ratio(-1062 * b1 + 1386 * b2, 793152)
    (p1 / 65536, p2 / 65536)
  }
  let x = solve(0)
  let y = solve(1)
  ((p0.at(0) / 65536, p0.at(1) / 65536),
   (x.at(0), y.at(0)), (x.at(1), y.at(1)),
   (p3.at(0) / 65536, p3.at(1) / 65536))
}
#let _mp-fixed-cubic-arc(points) = _mp-fixed-cubic-arc-raw(points.map(point =>
  point.map(axis => axis / 1mm / _mp-unit)))
#let _mp-cubic-split(points, t) = {
  let a = _mp-fixed-mix-point(points.at(0), points.at(1), t)
  let b = _mp-fixed-mix-point(points.at(1), points.at(2), t)
  let c = _mp-fixed-mix-point(points.at(2), points.at(3), t)
  let d = _mp-fixed-mix-point(a, b, t)
  let e = _mp-fixed-mix-point(b, c, t)
  let f = _mp-fixed-mix-point(d, e, t)
  (left: (points.at(0), a, d, f), right: (f, e, c, points.at(3)))
}
#let _mp-cubic-path-split(segments, t) = {
  let whole = calc.floor(t)
  let fraction = t - whole
  let left = segments.slice(0, whole)
  let right = ()
  if fraction > 0 {
    let parts = _mp-cubic-split(segments.at(whole), fraction)
    left.push(parts.left)
    right.push(parts.right)
    right += segments.slice(whole + 1)
  } else {
    right = segments.slice(whole)
  }
  (left: left, right: right)
}
#let _source-path-time-at(segments, path-time) = {
  let i = calc.min(int(calc.floor(path-time)), segments.len() - 1)
  let f = path-time - i
  let interval = segments.at(i)
  interval.at(0) + (interval.at(1) - interval.at(0)) * f
}
#let _source-path-time-inverse(segments, source-time) = {
  for (i, interval) in segments.enumerate() {
    let lo = calc.min(interval.at(0), interval.at(1))
    let hi = calc.max(interval.at(0), interval.at(1))
    if source-time >= lo - 1e-9 and source-time <= hi + 1e-9 {
      let span = interval.at(1) - interval.at(0)
      return if calc.abs(span) > 1e-12 {
        i + (source-time - interval.at(0)) / span
      } else { float(i) }
    }
  }
  none
}
#let _source-path-time-splice(segments, cut-time, half-gap: 0.05) = {
  let start-time = cut-time - half-gap
  let end-time = cut-time + half-gap
  let start-index = int(calc.floor(start-time))
  let end-index = int(calc.floor(end-time))
  let start-fraction = start-time - start-index
  let end-fraction = end-time - end-index
  let source-start = _source-path-time-at(segments, start-time)
  let source-end = _source-path-time-at(segments, end-time)
  let result = segments.slice(0, start-index)
  if start-fraction > 1e-9 {
    result.push((segments.at(start-index).at(0), source-start))
  }
  result.push((source-start, source-end))
  if end-fraction > 1e-9 {
    result.push((source-end, segments.at(end-index).at(1)))
  }
  let suffix = if end-fraction > 1e-9 { end-index + 1 } else { end-index }
  result += segments.slice(suffix)
  result
}
#let _mp-path-subdivision-times(n) = {
  let step = _mp-scalar-rounded(1 / n)
  let times = (0.0,)
  let t = 0.0
  while t < 1 {
    let next = _mp-scalar-rounded(t + step)
    if next < 1 {
      times.push(next)
      t = next
    } else {
      times.push(1.0)
      t = 1.0
    }
  }
  times
}

// ---------------------------------------------------------------------------
// vector helpers — points are (x, y) float pairs in mm
// ---------------------------------------------------------------------------
#let _add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let _sub(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let _mul(a, s) = (a.at(0) * s, a.at(1) * s)
#let _len(a) = calc.sqrt(a.at(0) * a.at(0) + a.at(1) * a.at(1))
#let _dist(a, b) = _len(_sub(a, b))
#let _unit(a) = {
  let l = _len(a)
  if l == 0 { (0.0, 0.0) } else { (a.at(0) / l, a.at(1) / l) }
}
#let _cross(a, b) = a.at(0) * b.at(1) - a.at(1) * b.at(0)
#let _rotate-vector(v, angle) = (
  v.at(0) * calc.cos(angle * 1deg) - v.at(1) * calc.sin(angle * 1deg),
  v.at(0) * calc.sin(angle * 1deg) + v.at(1) * calc.cos(angle * 1deg),
)
#let _mp-cubic-arclength-mm(curve) = {
  let raw = curve.map(point => point.map(axis => axis / _mp-unit))
  _mp-fixed-cubic-arc-raw(raw) / 65536 * _mp-unit
}
#let _mp-offset-boundary(curves, offsets) = {
  assert(curves.len() > 0 and offsets.len() == curves.len() + 1,
    message: "offset boundary needs one width per cubic knot")
  let joins = ()
  for i in range(curves.len() + 1) {
    let point = if i < curves.len() { curves.at(i).at(0) }
      else { curves.last().at(3) }
    let incoming = if i > 0 { curves.at(i - 1).at(2) } else { point }
    let outgoing = if i < curves.len() { curves.at(i).at(1) } else { point }
    if _dist(incoming, point) == 0 {
      incoming = _add(point, _sub(point, outgoing))
    }
    if _dist(outgoing, point) == 0 {
      outgoing = _add(point, _sub(point, incoming))
    }
    let in-normal = _rotate-vector(_unit(_sub(incoming, point)), -90)
    let out-normal = _rotate-vector(_unit(_sub(point, outgoing)), -90)
    let local-length = 0.0
    if i > 0 {
      let previous-half = _mp-cubic-split(curves.at(i - 1), 0.5).right
      local-length += _mp-cubic-arclength-mm(previous-half)
    }
    if i < curves.len() {
      let next-half = _mp-cubic-split(curves.at(i), 0.5).left
      local-length += _mp-cubic-arclength-mm(next-half)
    }
    let radius = offsets.at(i)
    let a1 = _add(_add(point, _mul(in-normal, radius)),
      _mul(_unit(_sub(point, incoming)), local-length))
    let b1 = _add(_add(point, _mul(in-normal, radius)),
      _mul(_unit(_sub(incoming, point)), local-length))
    let a2 = _add(_add(point, _mul(out-normal, radius)),
      _mul(_unit(_sub(point, outgoing)), local-length))
    let b2 = _add(_add(point, _mul(out-normal, radius)),
      _mul(_unit(_sub(outgoing, point)), local-length))
    let d1 = _sub(b1, a1)
    let d2 = _sub(b2, a2)
    let denominator = _cross(d1, d2)
    let hit = if calc.abs(denominator) > 1e-15 {
      let delta = _sub(a2, a1)
      let t = _cross(delta, d2) / denominator
      let u = _cross(delta, d1) / denominator
      (t: t, u: u, point: _add(a1, _mul(d1, t)))
    } else { none }
    let in-angle = calc.atan2(in-normal.at(0), in-normal.at(1)) / 1deg
    let out-angle = calc.atan2(out-normal.at(0), out-normal.at(1)) / 1deg
    let turn = calc.abs(in-angle - out-angle)
    let corner = (turn > 2 and hit != none and hit.t > 0 and hit.t <= 1
      and hit.u >= -1e-8 and hit.u <= 1 + 1e-8)
    joins.push(if corner { hit.point }
      else { _add(point, _mul(in-normal, radius)) })
  }
  range(curves.len()).map(i => {
    let curve = curves.at(i)
    let p0 = curve.at(0)
    let p1 = curve.at(1)
    let p2 = curve.at(2)
    let p3 = curve.at(3)
    let start = joins.at(i)
    let end = joins.at(i + 1)
    let q-x = _mp-cubic-arclength-mm(curve)
    let q-angle = calc.atan2(q-x, offsets.at(i + 1) - offsets.at(i)) / 1deg
    let local-end = _add(p3,
      _mul(_rotate-vector(_unit(_sub(p3, p2)), 90), offsets.at(i + 1)))
    let scale = _dist(start, local-end) / calc.max(1e-15, _dist(p0, p3))
    let control1 = _add(start, _mul(_rotate-vector(_sub(p1, p0), q-angle), scale))
    let control2 = _add(local-end,
      _mul(_rotate-vector(_sub(p2, p3), q-angle), scale))
    (start, control1, control2, end)
  })
}
#let _normal(a) = {
  let u = _unit(a)
  (-u.at(1), u.at(0))
}
#let _dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
#let _mod(a, b) = calc.rem(calc.rem(a, b) + b, b)
#let _rng(seed, key, salt) = {
  // A small keyed integer hash. The former affine LCG combine made keyed
  // streams arithmetic progressions (and visibly repeated every few rings
  // when keys advanced linearly). Squared modular rounds decorrelate adjacent
  // lanes while keeping every product exactly representable by Typst numbers.
  let m = 65521
  let s = _mod(int(seed), m)
  let k = _mod(int(key), m)
  let z = _mod(int(salt), m)
  let x = _mod((s + 17) * (s + 17) + 37 * (k + 31) * (k + 31)
    + 101 * (z + 11) * (z + 11), m)
  x = _mod((x + 1234) * (x + 1234) + 257 * s + 911 * k + 3571 * z, m)
  x / m
}

// MetaPost's default scaled arithmetic uses a 55-value subtractive stream.
// `randomseed := n` is converted to 16.16 before the stream is initialized.
#let _metapost-rng-raw-sequence(seed, count) = {
  assert(seed != 0, message: "MetaPost seed zero is time-dependent")
  let modulus = 268435456
  let j = int(calc.abs(seed) * 65536)
  while j >= modulus { j = int(calc.floor(j / 2)) }
  let k = 1
  let init = ()
  for _ in range(55) {
    let next-k = j - k
    j = k
    k = if next-k < 0 { next-k + modulus } else { next-k }
    init.push(j)
  }
  // (i * 21) mod 55 permutes all slots; 21 is its own inverse.
  let values = range(55).map(slot => init.at(_mod(slot * 21, 55)))
  let refill(values) = {
    let first = range(55).map(i => {
      if i <= 23 { _mod(values.at(i) - values.at(i + 31), modulus) }
      else { values.at(i) }
    })
    let second = first.slice(0, 24)
    for i in range(24, 55) {
      // The source updates this range in place, so indices 24–30 can be
      // consumed again later in the same refill.
      second.push(_mod(first.at(i) - second.at(i - 24), modulus))
    }
    second
  }
  for _ in range(3) { values = refill(values) }
  let out = ()
  let cursor = 54
  for _ in range(count) {
    if cursor == 0 {
      values = refill(values)
      cursor = 54
    } else { cursor -= 1 }
    out.push(values.at(cursor) / modulus)
  }
  out
}

#let _metapost-rng-sequence(seed, count) = {
  _metapost-rng-raw-sequence(seed, count).map(value =>
    calc.round(value * 65536) / 65536)
}

// One of MetaPost's eight cubic segments in fullcircle, rotated by 90°.
#let _mp-circle-point(t) = {
  let segment = int(_mod(calc.floor(t), 8))
  let u = t - calc.floor(t)
  let a0 = segment * 45
  let a1 = (segment + 1) * 45
  let p0 = (0.5 * calc.cos(a0 * 1deg), 0.5 * calc.sin(a0 * 1deg))
  let p1 = (0.5 * calc.cos(a1 * 1deg), 0.5 * calc.sin(a1 * 1deg))
  let h = 0.1326082449
  let c0 = _add(p0, _mul((-calc.sin(a0 * 1deg), calc.cos(a0 * 1deg)), h))
  let c1 = _sub(p1, _mul((-calc.sin(a1 * 1deg), calc.cos(a1 * 1deg)), h))
  let v = 1 - u
  let point = _add(
    _add(_mul(p0, v * v * v), _mul(c0, 3 * v * v * u)),
    _add(_mul(c1, 3 * v * u * u), _mul(p1, u * u * u)),
  )
  (-point.at(1), point.at(0))
}
// Typst's calc.cos/sin take angles; a bare number would be radians, so all
// public geometry APIs use plain degree numbers and convert here.
#let _cos(deg) = calc.cos(deg * 1deg)
#let _sin(deg) = calc.sin(deg * 1deg)
#let _lat-density(v, line) = {
  if v <= 1 / 256 { 0.0 } else {
    let order = calc.pow(2, calc.ceil(calc.log(1 / v, base: 2)))
    if calc.rem(line, order / 2) != 0 { 0.0 }
    else if calc.rem(line, order) == 0 { 1.0 }
    else { calc.max(0.0, v * order - 1) }
  }
}
#let _at(pts, i, closed) = {
  if closed { pts.at(_mod(i, pts.len())) } else { pts.at(calc.clamp(i, 0, pts.len() - 1)) }
}
#let _mm(p) = (p.at(0) * 1mm, p.at(1) * 1mm)
#let _join(items) = {
  if items.len() == 0 { none } else { items.slice(1).fold(items.at(0), (a, b) => a + b) }
}
#let _val(x, t) = if type(x) == function { x(t) } else { x }

// ---------------------------------------------------------------------------
// sampling — Hobby splines for open paths; Catmull–Rom for closed paths
// ---------------------------------------------------------------------------
#let _catmull(p0, p1, p2, p3, t) = {
  let t2 = t * t
  let t3 = t2 * t
  let f(a, b, c, d) = 0.5 * (
    2 * b
      + (-a + c) * t
      + (2 * a - 5 * b + 4 * c - d) * t2
      + (-a + 3 * b - 3 * c + d) * t3
  )
  (f(p0.at(0), p1.at(0), p2.at(0), p3.at(0)), f(p0.at(1), p1.at(1), p2.at(1), p3.at(1)))
}

// One unit-tension Hobby segment with fixed endpoint directions. Points and
// tangent vectors use the library's mm, y-down coordinates.
#let _hobby-given-cubic(start, end, start-tangent, end-tangent) = {
  let chord = (end.at(0) - start.at(0), start.at(1) - end.at(1))
  let chord-length = _len(chord)
  if chord-length <= 1e-10 { return none }
  let chord-angle = calc.atan2(chord.at(1), chord.at(0))
  let start-angle = calc.atan2(-start-tangent.at(1), start-tangent.at(0))
  let end-angle = calc.atan2(-end-tangent.at(1), end-tangent.at(0))
  let theta = start-angle - chord-angle
  let phi = chord-angle - end-angle
  let velocity(st, ct, sf, cf) = calc.min(4.0,
    (2 + calc.sqrt(2) * (st - sf / 16) * (sf - st / 16) * (ct - cf)) /
    (1.5 * (2 + (calc.sqrt(5) - 1) * ct + (3 - calc.sqrt(5)) * cf)))
  let rotate(v, angle) = (
    v.at(0) * calc.cos(angle) - v.at(1) * calc.sin(angle),
    v.at(0) * calc.sin(angle) + v.at(1) * calc.cos(angle),
  )
  let r = velocity(calc.sin(theta), calc.cos(theta),
    calc.sin(phi), calc.cos(phi))
  let s = velocity(calc.sin(phi), calc.cos(phi),
    calc.sin(theta), calc.cos(theta))
  let start-up = (start.at(0), -start.at(1))
  let end-up = (end.at(0), -end.at(1))
  let c1 = _add(start-up, _mul(rotate(chord, theta), r))
  let c2 = _sub(end-up, _mul(rotate(chord, -phi), s))
  (start, (c1.at(0), -c1.at(1)), (c2.at(0), -c2.at(1)), end)
}

/// Catmull–Rom sampler retained for closed paths and explicit selection.
#let _resample-catmull(pts, per: 12, closed: false) = {
  let segs = if closed { pts.len() } else { pts.len() - 1 }
  let out = ()
  for s in range(segs) {
    let p0 = _at(pts, s - 1, closed)
    let p1 = _at(pts, s, closed)
    let p2 = _at(pts, s + 1, closed)
    let p3 = _at(pts, s + 2, closed)
    for k in range(per) {
      out.push(_catmull(p0, p1, p2, p3, k / per))
    }
  }
  if not closed { out.push(pts.at(pts.len() - 1)) }
  out
}

// Hobby's unit-tension automatic spline. Endpoints use unit curl; the open
// tridiagonal mock-curvature system is solved in linear time.
#let _hobby-controls(pts) = {
  let n = pts.len()
  if n < 3 { return none }
  let m = n - 1
  let chords = range(m).map(i => (
    pts.at(i + 1).at(0) - pts.at(i).at(0),
    pts.at(i).at(1) - pts.at(i + 1).at(1),
  ))
  let lengths = chords.map(v => _len(v))
  if lengths.any(d => d <= 1e-10) { return none }

  let turns = range(n).map(_ => 0.0)
  for i in range(1, m) {
    let a = chords.at(i - 1)
    let b = chords.at(i)
    let cross = a.at(0) * b.at(1) - a.at(1) * b.at(0)
    let dot = a.at(0) * b.at(0) + a.at(1) * b.at(1)
    turns.at(i) = calc.atan2(dot, cross) / 1rad
  }

  let lower = ()
  let diagonal = ()
  let upper = ()
  let rhs = ()
  for k in range(n) {
    if k == 0 {
      lower.push(0.0)
      diagonal.push(1.0)
      upper.push(1.0)
      rhs.push(-turns.at(1))
    } else if k == m {
      lower.push(1.0)
      diagonal.push(1.0)
      upper.push(0.0)
      rhs.push(0.0)
    } else {
      let ratio = lengths.at(k) / lengths.at(k - 1)
      lower.push(ratio)
      diagonal.push(2 * ratio + 2)
      upper.push(1.0)
      rhs.push(-2 * ratio * turns.at(k) - turns.at(k + 1))
    }
  }
  for i in range(1, n) {
    let factor = lower.at(i) / diagonal.at(i - 1)
    diagonal.at(i) -= factor * upper.at(i - 1)
    rhs.at(i) -= factor * rhs.at(i - 1)
  }
  let theta = range(n).map(_ => 0.0)
  theta.at(m) = rhs.at(m) / diagonal.at(m)
  for offset in range(m) {
    let i = m - 1 - offset
    theta.at(i) = (rhs.at(i) - upper.at(i) * theta.at(i + 1)) / diagonal.at(i)
  }

  let velocity(st, ct, sf, cf) = calc.min(4.0,
    (2 + calc.sqrt(2) * (st - sf / 16) * (sf - st / 16) * (ct - cf)) /
    (1.5 * (2 + (calc.sqrt(5) - 1) * ct + (3 - calc.sqrt(5)) * cf)))
  let rotate(v, a) = (
    v.at(0) * calc.cos(a) - v.at(1) * calc.sin(a),
    v.at(0) * calc.sin(a) + v.at(1) * calc.cos(a),
  )
  range(m).map(i => {
    let phi = -turns.at(i + 1) - theta.at(i + 1)
    let a = theta.at(i)
    let v = chords.at(i)
    let start = (pts.at(i).at(0), -pts.at(i).at(1))
    let end = (pts.at(i + 1).at(0), -pts.at(i + 1).at(1))
    let r = velocity(calc.sin(a), calc.cos(a), calc.sin(phi), calc.cos(phi))
    let s = velocity(calc.sin(phi), calc.cos(phi), calc.sin(a), calc.cos(a))
    let c1 = _add(start, _mul(rotate(v, a), r))
    let c2 = _sub(end, _mul(rotate(v, -phi), s))
    (pts.at(i), (c1.at(0), -c1.at(1)), (c2.at(0), -c2.at(1)), pts.at(i + 1))
  })
}

#let _hobby-resample(pts, per: 12) = {
  let cubics = _hobby-controls(pts)
  if cubics == none { return none }
  let out = ()
  for seg in cubics {
    let point(t) = {
      let u = 1 - t
      _add(
        _add(_mul(seg.at(0), u * u * u), _mul(seg.at(1), 3 * u * u * t)),
        _add(_mul(seg.at(2), 3 * u * t * t), _mul(seg.at(3), t * t * t)),
      )
    }
    for k in range(per) { out.push(point(k / per)) }
  }
  out.push(pts.last())
  out
}

/// Resample a polyline. Open paths default to MetaPost-style Hobby splines;
/// closed paths use periodic Catmull–Rom. Set `spline: "catmull"` to retain
/// Catmull–Rom on an open path, or `spline: "hobby"` to request Hobby there.
#let resample(pts, per: 12, closed: false, spline: "auto") = {
  if not closed and (spline == "auto" or spline == "hobby") {
    let result = _hobby-resample(pts, per: per)
    if result != none { return result }
  }
  _resample-catmull(pts, per: per, closed: closed)
}

/// Tangent/normal frames along a dense point list.
#let _frame(pts, closed) = {
  pts.enumerate().map(((i, p)) => {
    let d = _sub(_at(pts, i + 1, closed), _at(pts, i - 1, closed))
    let u = _unit(d)
    (p, (-u.at(1), u.at(0)))
  })
}

#let _prepare(pts, per, closed) = if per > 0 { resample(pts, per: per, closed: closed) } else { pts }

// Normalized cumulative path lengths at each sampled point. The final closing
// segment contributes to total length but has no duplicate point at t = 1.
#let _path-fractions(pts, closed) = {
  let n = pts.len()
  if n == 0 { return () }
  let count = if closed { n } else { n - 1 }
  let lengths = (0.0,)
  for i in range(count) {
    lengths.push(lengths.last() + _dist(pts.at(i), pts.at(_mod(i + 1, n))))
  }
  let total = lengths.last()
  range(n).map(i => if total > 0 { lengths.at(i) / total }
                    else if closed { i / n }
                    else if n > 1 { i / (n - 1) }
                    else { 0.0 })
}

// ---------------------------------------------------------------------------
// ink machinery — variable-width bands, ink-conserving dashes
// ---------------------------------------------------------------------------

/// Build closed loops (for filling) from frames + per-point widths.
/// Widths below `minw` are replaced by dashes of width `minw` whose coverage
/// (dash length / period) equals w / minw, keeping ink per unit length.
#let _ink-loops(fr, ws, closed, minw, minlen, seed: 0, dash-extra: 0, dash-cap: 0,
                random-stream: none, rng-offset: 0,
                with-rng: false, with-stats: false,
                param-times: none, param-end: none, trace-nodes: false,
                source-rounding: false, width-by-arc: false,
                source-width-fixed: none, source-q-curves-fixed: none,
                source-arc-positions: none) = {
  let n = fr.len()
  let step = (minw - minw / 3) / 16
  let dash-floor = minw / 3 + dash-extra
  let loops = ()
  let rng-cursor = 0
  let thin-leaf-count = 0
  let outer-leaf-count = 0
  let nodes = ()
  let adj = range(n).map(i => {
    let j = if closed { _mod(i + 1, n) } else { calc.clamp(i + 1, 0, n - 1) }
    _dist(fr.at(i).at(0), fr.at(j).at(0))
  })
  let arc-positions = if width-by-arc {
    let positions = (0.0,)
    for i in range(if closed { n } else { n - 1 }) {
      positions.push(positions.last() + adj.at(i))
    }
    positions
  } else { () }

  let width-interpolate(a, b, f) = if source-rounding {
    let q = _mp-scalar-rounded(f)
    let one-minus-q = _mp-scalar-rounded(1 - q)
    _mp-rounded(_mp-rounded(a * one-minus-q) + _mp-rounded(b * q))
  } else { a * (1 - f) + b * f }

  // Fractional sample coordinates let recursive cuts land exactly where the
  // width template crosses its target, as cutPathTime does in MetaPost.
  let frame-index(s) = {
    let base = calc.floor(s)
    let t = s - base
    let i = if closed { _mod(base, n) } else { calc.clamp(base, 0, n - 1) }
    let j = if closed { _mod(base + 1, n) } else { calc.clamp(base + 1, 0, n - 1) }
    let a = fr.at(i)
    let b = fr.at(j)
    (
      _add(a.at(0), _mul(_sub(b.at(0), a.at(0)), t)),
      _unit(_add(a.at(1), _mul(_sub(b.at(1), a.at(1)), t))),
    )
  }
  let width-index(s) = {
    let value = if width-by-arc {
      let base = calc.floor(s)
      let t = s - base
      let i = if closed { _mod(base, n) } else { calc.clamp(base, 0, n - 1) }
      let edge = if closed { i } else { calc.min(i, n - 2) }
      let arc = if (closed and s >= n) or (not closed and s >= n - 1) {
        arc-positions.last()
      }
        else { arc-positions.at(edge) + t * adj.at(edge) }
      let segment = range(if closed { n } else { n - 1 }).find(k =>
        arc-positions.at(k) <= arc and arc <= arc-positions.at(k + 1))
      let k = if segment == none { if closed { n - 1 } else { n - 2 } } else { segment }
      let span = arc-positions.at(k + 1) - arc-positions.at(k)
      let f = if span > 0 { calc.clamp((arc - arc-positions.at(k)) / span, 0.0, 1.0) } else { 0.0 }
      let j = if closed { _mod(k + 1, n) } else { k + 1 }
      width-interpolate(ws.at(k), ws.at(j), f)
    } else {
      let base = calc.floor(s)
      let t = s - base
      let i = if closed { _mod(base, n) } else { calc.clamp(base, 0, n - 1) }
      let j = if closed { _mod(base + 1, n) } else { calc.clamp(base + 1, 0, n - 1) }
      width-interpolate(ws.at(i), ws.at(j), t)
    }
    value
  }
  // Optional source-template time. Some callers retain the width template's
  // original knots, whose path parameter is not uniform in physical length.
  let param-at(s) = if param-times == none { s } else {
    let base = calc.floor(s)
    let t = s - base
    if closed and base >= n - 1 {
      let end = if param-end == none { param-times.last() } else { param-end }
      param-times.last() + (s - (n - 1)) * (end - param-times.last())
    } else {
      let i = if closed { _mod(base, n) } else { calc.clamp(base, 0, n - 1) }
      let j = if closed { _mod(base + 1, n) } else { calc.clamp(base + 1, 0, n - 1) }
      param-times.at(i) * (1 - t) + param-times.at(j) * t
    }
  }
  let source-q-cubic(a, b) = {
    let x1 = a.at(0) + _mp-rounded((b.at(0) - a.at(0)) / 3)
    let y1 = a.at(1) + _mp-rounded((b.at(1) - a.at(1)) / 3)
    let x2 = a.at(0) + _mp-rounded(2 * (b.at(0) - a.at(0)) / 3)
    let y2 = a.at(1) + _mp-rounded(2 * (b.at(1) - a.at(1)) / 3)
    (a, (x1, y1), (x2, y2), b)
  }
  let source-q-split(curves, qtime) = {
    let whole = int(calc.clamp(calc.floor(qtime), 0, curves.len() - 1))
    let fraction = _mp-scalar-rounded(calc.clamp(qtime - whole, 0.0, 1.0))
    let left = curves.slice(0, whole)
    let right = ()
    if fraction > 0 {
      let parts = _mp-cubic-split(curves.at(whole), fraction)
      left.push(parts.left)
      right.push(parts.right)
      right += curves.slice(whole + 1)
    } else { right = curves.slice(whole) }
    (left: left, right: right, whole: whole, fraction: fraction)
  }
  let source-q-map-split(qmap, split) = {
    let left = qmap.slice(0, split.whole)
    let right = ()
    if split.fraction > 0 {
      let bounds = qmap.at(split.whole)
      let cut = bounds.at(0) + split.fraction * (bounds.at(1) - bounds.at(0))
      left.push((bounds.at(0), cut))
      right.push((cut, bounds.at(1)))
      right += qmap.slice(split.whole + 1)
    } else { right = qmap.slice(split.whole) }
    (left: left, right: right)
  }
  let source-q-bounds(curves) = {
    let widths = ()
    for curve in curves { for point in curve { widths.push(point.at(1)) } }
    (calc.min(..widths), calc.max(..widths))
  }
  let source-q-fixed(curves) = curves.map(curve => curve.map(point => (
    int(calc.round(point.at(0) / _mp-unit * 65536)),
    int(calc.round(point.at(1) / _mp-unit * 65536)),
  )))
  let source-q-point(curves, time) = {
    let whole = int(calc.clamp(calc.floor(time), 0, curves.len() - 1))
    let fraction = calc.clamp(time - whole, 0.0, 1.0)
    _mp-cubic-split(curves.at(whole), fraction).left.at(3)
  }
  let source-path-at-time(path, time) = {
    let result = path.first()
    for i in range(path.len() - 1) {
      let a = param-at(path.at(i))
      let b = param-at(path.at(i + 1))
      if (a <= time and time <= b) or (b <= time and time <= a) {
        let f = if b == a { 0.0 } else { (time - a) / (b - a) }
        result = path.at(i) + f * (path.at(i + 1) - path.at(i))
        break
      }
    }
    result
  }
  // Some traced outlines carry more accurate cumulative lengths than their
  // rendering polyline, e.g. sampled points on MetaPost cubic horizon arcs.
  let source-path-arc(path, at) = {
    if source-arc-positions != none {
      let sample-at(time) = {
        let index = int(calc.clamp(calc.floor(time), 0,
          source-arc-positions.len() - 2))
        let fraction = calc.clamp(time - index, 0.0, 1.0)
        (source-arc-positions.at(index) * (1 - fraction)
          + source-arc-positions.at(index + 1) * fraction)
      }
      return sample-at(at) - sample-at(path.first())
    }
    let total = 0.0
    for i in range(path.len() - 1) {
      let span = _dist(frame-index(path.at(i)).at(0), frame-index(path.at(i + 1)).at(0))
      if at >= path.at(i + 1) { total += span }
      else if at > path.at(i) {
        total += span * (at - path.at(i)) / (path.at(i + 1) - path.at(i))
        break
      } else { break }
    }
    total
  }
  let source-cut-valid(path, cut, margin) = {
    let start = param-at(path.first())
    let end = param-at(path.last())
    let at = param-at(cut)
    let first-end = calc.min(calc.floor(start) + 1, end)
    let head = if at >= first-end - 0.000000001 { true }
      else { (at - start) / (first-end - start) > margin }
    let last-start = if calc.abs(end - calc.round(end)) < 0.000000001 { end - 1 }
      else { calc.floor(end) }
    let last-start = calc.max(start, last-start)
    let tail = if at <= last-start + 0.000000001 { true }
      else { (end - at) / (end - last-start) > margin }
    head and tail
  }
  let source-path-time(path, cut) = {
    let start = param-at(path.first())
    let at = param-at(cut)
    let first-end = calc.min(calc.floor(start) + 1, param-at(path.last()))
    if at < first-end - 0.000000001 {
      (at - start) / (first-end - start)
    } else {
      1 + calc.max(0, calc.floor(at) - first-end) + at - calc.floor(at)
    }
  }
  // Preserve q-intersection failure details in node traces. Without an
  // explicit trace request, failed cuts keep the ordinary `none` result.
  let source-q-split-path(path, target, margin, qcurves, qmap,
                          report-failure: false) = {
    let total = 0.0
    for i in range(path.len() - 1) {
      total += _dist(frame-index(path.at(i)).at(0), frame-index(path.at(i + 1)).at(0))
    }
    let points = ()
    for curve in qcurves { for point in curve { points.push(point) } }
    let xs = points.map(point => point.at(0))
    let x-min = calc.min(..xs)
    let x-max = calc.max(..xs)
    if x-max <= x-min {
      if not report-failure { return none }
      return ((), (), 0.0, 0.0, 0.0, total, false, none, none,
        none, none, none, none, none,
        (status: "degenerate-width", x-min: x-min, x-max: x-max))
    }
    let midpoint = if source-rounding {
      // MetaPost first adds fixed-point bounds, then rounds the half-product
      // upward when their sum lands exactly between representable values.
      let x-min-fixed = int(calc.round(x-min / _mp-unit * 65536))
      let x-max-fixed = int(calc.round(x-max / _mp-unit * 65536))
      int(calc.floor((x-min-fixed + x-max-fixed + 1) / 2)) / 65536 * _mp-unit
    } else { (x-min + x-max) / 2 }
    let height = if source-rounding { _mp-rounded(target) } else { target }
    let ray-right = source-q-fixed((source-q-cubic((midpoint, height), (x-max, height)),))
    let ray-left = source-q-fixed((source-q-cubic((midpoint, height), (x-min, height)),))
    let fixed-curves = source-q-fixed(qcurves)
    let right-hit = intersection-times(ray-right.first(), fixed-curves)
    let left-hit = intersection-times(ray-left.first(), fixed-curves)
    let right-time = right-hit.at(1)
    let left-time = left-hit.at(1)
    if right-time < 0 and left-time < 0 {
      if not report-failure { return none }
      return ((), (), 0.0, 0.0, 0.0, total, false, none, none,
        none, none, none, none, none,
        (status: "no-intersection", right-time: right-time,
          left-time: left-time, midpoint: midpoint, target: height,
          x-min: x-min, x-max: x-max))
    }
    let right-x = if right-time < 0 { 0.0 } else { source-q-point(qcurves, right-time).at(0) }
    let left-x = if left-time < 0 { 0.0 } else { source-q-point(qcurves, left-time).at(0) }
    let closer-right = if source-rounding {
      // MetaPost compares the two rounded hit x coordinates against its
      // rounded midpoint. A float comparison can reverse a one-unit tie.
      let midpoint-fixed = int(calc.round(midpoint / _mp-unit * 65536))
      let right-fixed = int(calc.round(right-x / _mp-unit * 65536))
      let left-fixed = int(calc.round(left-x / _mp-unit * 65536))
      calc.abs(right-fixed - midpoint-fixed) < calc.abs(left-fixed - midpoint-fixed)
    } else { calc.abs(right-x - midpoint) < calc.abs(left-x - midpoint) }
    let qtime = if right-time < 0 { left-time }
      else if left-time < 0 { right-time }
      else if closer-right { right-time }
      else { left-time }
    let segment = int(calc.clamp(calc.floor(qtime), 0, qmap.len() - 1))
    let fraction = calc.clamp(qtime - segment, 0.0, 1.0)
    let bounds = qmap.at(segment)
    let source-time = bounds.at(0) + fraction * (bounds.at(1) - bounds.at(0))
    let cut = source-path-at-time(path, source-time)
    let arc = source-path-arc(path, cut)
    // `cutPathTime` returns a parameter on q, and MetaPost passes that same
    // local parameter to `subpath` on p. Compare the endpoint guard in this
    // shared path-segment domain; mapping it through qmap to the sampled
    // centerline changes its scale and can reject valid source cuts.
    let valid = if qmap != none {
      qtime > margin and qtime < qcurves.len() - margin
    } else if param-times == none {
      let local-cut = source-path-time(path, cut)
      let local-end = source-path-time(path, path.last())
      local-cut > margin and local-cut < local-end - margin
    } else { source-cut-valid(path, cut, margin) }
    if not valid {
      if not report-failure { return none }
      return ((), (), 0.0, 0.0, 0.0, total, false, none, none,
        none, none, none, none, none,
        (status: "invalid-cut", right-time: right-time,
          left-time: left-time, qtime: qtime, source-time: source-time,
          cut: cut, arc: arc, total: total, midpoint: midpoint, target: height))
    }
    let edge = range(path.len() - 1).find(i => path.at(i) <= cut and cut <= path.at(i + 1))
    let q = if edge == none { path.len() - 2 } else { edge }
    let left-path = path.slice(0, q + 1) + (cut,)
    let right-path = (cut,) + path.slice(q + 1)
    let qsplit = source-q-split(qcurves, qtime)
    let mapsplit = source-q-map-split(qmap, qsplit)
    let llen = source-path-arc(path, cut)
    let rlen = total - llen
    (left-path, right-path, llen, rlen, arc, total, valid,
      source-path-time(path, cut), frame-index(cut).at(0),
      qsplit.left, qsplit.right, mapsplit.left, mapsplit.right, qtime,
      (status: "split", right-time: right-time, left-time: left-time,
        right-x: right-x, left-x: left-x,
        qtime: qtime, source-time: source-time, cut: cut, arc: arc,
        total: total, midpoint: midpoint, target: height))
  }
  let split-path(path, target, margin: _source-brush-time-guard,
                 qcurves: none, qmap: none,
                 report-failure: false) = {
    if qcurves != none {
      return source-q-split-path(path, target, margin, qcurves, qmap,
        report-failure: report-failure)
    }
    let total = 0.0
    for q in range(path.len() - 1) {
      total += _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
    }
    let best-distance = 1e99
    let crossing = none
    let arc = 0.0
    // MetaPost's cutPathTime resolves equidistant crossings toward the
    // second ray hit (the earlier path-time). Tiny floating-point asymmetry
    // in accumulated arc lengths must not reverse that source tie-break.
    let tie-tolerance = if source-rounding { 1e-9 * calc.max(1.0, total) } else { 0.0 }
    for q in range(path.len() - 1) {
      let a = width-index(path.at(q))
      let b = width-index(path.at(q + 1))
      let span = _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
      if a != b and ((a <= target and b >= target) or (a >= target and b <= target)) {
        let raw-f = calc.clamp((target - a) / (b - a), 0.0, 1.0)
        // MetaPost quantizes each firstIntersectionTimes result before it
        // compares the two hits around the midpoint. Keep this local hit
        // rounding here; the selected whole-path parameter is rounded again
        // when it is mapped back onto the input path below.
        let f = if source-rounding { _mp-scalar-rounded(raw-f) } else { raw-f }
        let at = arc + f * span
        let distance = calc.abs(at - total / 2)
        if distance < best-distance - tie-tolerance {
          best-distance = distance
          crossing = (q, f, at)
        }
      }
      arc += span
    }
    if crossing == none { none } else {
      let q = crossing.at(0)
      let f = crossing.at(1)
      let at = crossing.at(2)
      let raw-cut = path.at(q) + (path.at(q + 1) - path.at(q)) * f
      let cut = if source-rounding and param-times == none {
        _mp-scalar-rounded(raw-cut)
      } else { raw-cut }
      // thinBrushGenerate's endpoint guard is expressed in path time. In
      // source-rounded mode `cut` is that quantized parameter; comparing the
      // same margin to physical arc length changes recursion near crossings.
      let valid = if param-times == none and source-rounding {
        let local-cut = source-path-time(path, cut)
        let local-end = source-path-time(path, path.last())
        local-cut > margin and local-cut < local-end - margin
      } else if param-times == none { at > margin and total - at > margin }
        else { source-cut-valid(path, cut, margin) }
      if not valid { none } else {
        let left = path.slice(0, q + 1) + (cut,)
        let right = (cut,) + path.slice(q + 1)
        let llen = range(left.len() - 1).map(i => _dist(frame-index(left.at(i)).at(0), frame-index(left.at(i + 1)).at(0))).sum()
        let rlen = range(right.len() - 1).map(i => _dist(frame-index(right.at(i)).at(0), frame-index(right.at(i + 1)).at(0))).sum()
        (left, right, llen, rlen, at, total, valid,
          source-path-time(path, cut), frame-index(cut).at(0),
          none, none, none, none)
      }
    }
  }

  // solid band through a contiguous run of samples
  let band(pos, fixed: none) = {
    let fwd = ()
    let bwd = ()
    for k in pos {
      let e = frame-index(k)
      let p = e.at(0)
      let nv = e.at(1)
      let h = (if fixed == none { width-index(k) } else { fixed }) / 2
      fwd.push(_add(p, _mul(nv, h)))
      bwd.push(_sub(p, _mul(nv, h)))
    }
    fwd + bwd.rev()
  }

  // dashes through a run that is too thin to print solid
  let dashband(pos, target-width: none) = {
    let out = ()
    let cumulative = (0.0,)
    let total = 0.0
    let width-sum = 0.0
    let seg-count = if closed and pos.len() == n { pos.len() } else { pos.len() - 1 }
    for i in range(pos.len()) {
      width-sum += width-index(pos.at(i))
      if i < seg-count {
        let j = if i + 1 < pos.len() { i + 1 } else { 0 }
        total += _dist(frame-index(pos.at(i)).at(0), frame-index(pos.at(j)).at(0))
        cumulative.push(total)
      }
    }
    let w = width-sum / pos.len()
    // The source drops widths below one third of its printable pen. For the
    // remaining thin strokes it fits an integer number of dashes to each
    // nearly constant-width path, then centers the phase at both ends.
    if (target-width == none and w < dash-floor) or total <= 0 { return (out, 0) }
    // The reference draws short paths with its minimum pen instead of trying
    // to squeeze a dash pattern into a segment shorter than minDashStrokeLength.
    if total <= minlen {
      out.push(band(pos, fixed: minw))
      return (out, 0)
    }
    // thinBrushGenerate rounds each printable dash width down to one of
    // sixteen fixed levels before it computes dash coverage.
    let qw = if target-width == none {
      minw / 3 + calc.floor((w - minw / 3) / step) * step
    } else { target-width }
    let c = calc.clamp(qw / minw, 0.0, 1.0)
    // MetaPost's thinBrushPattern uses half the minimum dash length,
    // scaled by the width coverage raised to 5/2.
    let p0 = frame-index(pos.at(0)).at(0)
    let key = int(calc.round(p0.at(0) * 10000)) * 1009 + int(calc.round(p0.at(1) * 10000))
    let jitter = if random-stream == none { _rng(seed, key, 1) }
      else { random-stream.at(rng-offset + rng-cursor) }
    let base-dash = minlen * (1 + calc.pow(c, 2.5)) / 2
    let dash0 = if random-stream == none {
      base-dash * (1 + 0.5 * jitter)
    } else {
      // MetaPost scales `uniformdeviate(d1)` in 16.16 bp units before adding
      // half of it to d1; preserve that rounding at the same unit boundary.
      base-dash + 0.5 * calc.round(base-dash / _mp-unit * jitter * 65536) / 65536 * _mp-unit
    }
    let gap0 = (minw - qw) * dash0 / qw
    let count = calc.max(1, calc.round(total / (dash0 + gap0)))
    let period = total / count
    let dash = period * c
    let gap = period - dash
    // Seeded, stable half-period choice. The same seed preserves this pattern;
    // a different seed changes it without introducing mutable global state.
    let centered-on = if random-stream == none { _rng(seed, key, 2) < 0.5 }
      else { random-stream.at(rng-offset + rng-cursor + 1) > 0.5 }

    // Locate the first segment boundary at (or strictly after) an arc length.
    let boundary(s, strict: false) = {
      let lo = 0
      let hi = seg-count
      while lo < hi {
        let mid = int(calc.floor((lo + hi) / 2))
        let hit = if strict { cumulative.at(mid + 1) > s } else { cumulative.at(mid + 1) >= s }
        if hit { hi = mid } else { lo = mid + 1 }
      }
      calc.min(lo + 1, seg-count)
    }
    let frame-at(s) = {
      let i = boundary(s) - 1
      let j = if i + 1 < pos.len() { i + 1 } else { 0 }
      let span = cumulative.at(i + 1) - cumulative.at(i)
      let t = if span > 0 { calc.clamp((s - cumulative.at(i)) / span, 0.0, 1.0) } else { 0.0 }
      let a = frame-index(pos.at(i))
      let b = frame-index(pos.at(j))
      let p = _add(a.at(0), _mul(_sub(b.at(0), a.at(0)), t))
      let nv = _unit(_add(a.at(1), _mul(_sub(b.at(1), a.at(1)), t)))
      (p, nv)
    }

    let draw-dash(a, b) = {
      if b <= a { none } else {
        let frames = (frame-at(a),)
        let first = boundary(a, strict: true)
        let last = boundary(b)
        for i in range(first, last) {
          frames.push(frame-index(pos.at(i)))
        }
        frames.push(frame-at(b))
        let fwd = ()
        let bwd = ()
        for (idx, e) in frames.enumerate() {
          fwd.push(_add(e.at(0), _mul(e.at(1), minw / 2)))
          bwd.push(_sub(e.at(0), _mul(e.at(1), minw / 2)))
        }
        let body = fwd + bwd.rev()
        if dash-cap == 1 {
          (body,
           (center: frames.first().at(0), diameter: minw, reverse: true),
           (center: frames.last().at(0), diameter: minw, reverse: true))
        } else { (body,) }
      }
    }

    if centered-on {
      for k in range(int(count) + 1) {
        let center = k * period
        let lp = draw-dash(calc.max(0.0, center - dash / 2), calc.min(total, center + dash / 2))
        if lp != none { out += lp }
      }
    } else {
      for k in range(int(count)) {
        let start = gap / 2 + k * period
        let lp = draw-dash(start, calc.min(total, start + dash))
        if lp != none { out += lp }
      }
    }
    (out, 2)
  }

  // Split thin runs at a width crossing. Each leaf is one nearly
  // constant-width dashed path.
  let refine-thin(pos, initial-q: none, initial-qmap: none) = {
    let pending = ((pos, initial-q, initial-qmap, 0),)
    let leaves = ()
    let thin-nodes = ()
    while pending.len() > 0 {
      let node = pending.pop()
      let path = node.at(0)
      let qcurves = node.at(1)
      let qmap = node.at(2)
      let depth = node.at(3)
      let lo = width-index(path.at(0))
      let hi = lo
      let total = 0.0
      for q in range(path.len()) {
        let w = width-index(path.at(q))
        lo = calc.min(lo, w)
        hi = calc.max(hi, w)
        if q + 1 < path.len() {
          total += _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
        }
      }
      if qcurves != none {
        let qbounds = source-q-bounds(qcurves)
        lo = qbounds.at(0)
        hi = qbounds.at(1)
      }
      let source-min = if not source-rounding { minw } else { _mp-rounded(minw) }
      let base = if not source-rounding { minw / 3 } else {
        _mp-rounded(source-min / 3)
      }
      // thinBrushGenerate enters its width-cut branch only when the upper
      // width bound clears minWidth by 1/100 bp. Keep that source guard
      // separate from the dash floor used to choose the target width.
      let thin-eligible = if source-rounding and qcurves != none {
        let guard = _mp-rounded(base + _source-brush-width-guard)
        hi > guard
      } else { hi > dash-floor }
      let thin-step = if not source-rounding { step } else {
        _mp-rounded(_mp-rounded(source-min - base) / 16)
      }
      let midpoint = if not source-rounding { (hi + lo) / 2 }
        else { _mp-rounded(_mp-rounded(hi + lo) / 2) }
      let level = if not source-rounding {
        calc.floor((midpoint - base) / thin-step)
      } else {
        calc.floor(_mp-scalar-rounded(_mp-rounded(midpoint - base) / thin-step))
      }
      let target = if lo > base - _source-brush-width-guard {
        let width = base + level * thin-step
        if not source-rounding { width } else { _mp-rounded(width) }
      } else { base }
      let candidate = if thin-eligible {
        split-path(path, target, qcurves: qcurves, qmap: qmap,
          report-failure: trace-nodes)
      } else { none }
      let split = if candidate != none and (candidate.at(2) > minlen or candidate.at(3) > minlen) {
        (candidate.at(0), candidate.at(1),
          if qcurves == none { none } else { candidate.at(9) },
          if qcurves == none { none } else { candidate.at(10) },
          if qcurves == none { none } else { candidate.at(11) },
          if qcurves == none { none } else { candidate.at(12) })
      } else { none }
      // thinBrushGenerate only attempts a width cut when its upper corner
      // exceeds the dash floor by the source's 0.01 bp guard.
      let width-span-ok = if source-rounding and qcurves != none {
        let lo-fixed = int(calc.round(lo / _mp-unit * 65536))
        let hi-fixed = int(calc.round(hi / _mp-unit * 65536))
        let step-fixed = int(calc.round(thin-step / _mp-unit * 65536))
        hi-fixed - lo-fixed >= step-fixed
      } else { hi - lo >= step }
      let recurse = thin-eligible and width-span-ok
        and depth < _source-thin-brush-depth and split != none
      if trace-nodes {
        thin-nodes.push((stage: "thin", depth: depth, width-min: lo, width-max: hi,
          width-start: width-index(path.first()),
          width-end: width-index(path.last()),
          target: target, width-base: base, width-step: thin-step, length: total,
          eligible: thin-eligible,
          width-span-ok: width-span-ok,
          width-span-fixed: if qcurves == none { none } else {
            (int(calc.round(hi / _mp-unit * 65536))
              - int(calc.round(lo / _mp-unit * 65536)),
              int(calc.round(thin-step / _mp-unit * 65536)))
          },
          path-start: frame-index(path.first()).at(0),
          path-end: frame-index(path.last()).at(0),
          cut-point: if candidate == none { none } else { candidate.at(8) },
          has-cut: candidate != none and (qcurves == none or candidate.at(14).status == "split"),
          cut-distance: if candidate == none { none } else { candidate.at(4) },
          cut-param: if candidate == none { none } else { candidate.at(7) },
          q-cut-time: if candidate == none or qcurves == none { none } else { candidate.at(13) },
          split-debug: if qcurves == none or candidate == none { none }
            else { candidate.at(14) },
          left-length: if candidate == none { 0.0 } else { candidate.at(2) },
          right-length: if candidate == none { 0.0 } else { candidate.at(3) },
          recurse: recurse,
          q-map: qmap,
          q-curves-fixed: if qcurves == none { none } else { source-q-fixed(qcurves) },
          // A terminal thin node consumes two source RNG values only when it
          // reaches thinBrushPattern: it must be below minw and long enough
          // for dash placement. Keep this decision visible in trace mode.
          dash: not recurse and hi > dash-floor and target < minw and total > minlen))
      }
      if recurse {
        pending.push((split.at(1), split.at(3), split.at(5), depth + 1))
        pending.push((split.at(0), split.at(2), split.at(4), depth + 1))
      } else if thin-eligible {
        leaves.push((path, calc.min(minw, target), qcurves, qmap))
      }
    }
    (leaves, thin-nodes)
  }

  // Reproduce brushGenerate's outer recursion: split the whole path at each
  // minStrokeWidth crossing, choosing cutPathTime's midpoint-nearest crossing.
  let initial-path = if closed { range(n + 1).map(i => float(i)) } else { range(n).map(i => float(i)) }
  let source-time-start = if param-times == none { 0.0 } else { param-times.first() }
  let initial-q = if source-q-curves-fixed != none {
    source-q-curves-fixed.map(curve => curve.map(point => (
      point.at(0) / 65536 * _mp-unit,
      point.at(1) / 65536 * _mp-unit,
    )))
  } else if source-width-fixed == none { none } else {
    let qpoints = range(source-width-fixed.len()).map(i => {
      let source-time = source-time-start + i
      let path-time = source-path-at-time(initial-path, source-time)
      let arc = source-path-arc(initial-path, path-time)
      (arc, source-width-fixed.at(i) / 65536 * _mp-unit)
    })
    range(qpoints.len() - 1).map(i => source-q-cubic(qpoints.at(i), qpoints.at(i + 1)))
  }
  let initial-qmap = if initial-q == none { none } else {
    range(initial-q.len()).map(i => (source-time-start + i, source-time-start + i + 1))
  }
  let pending = ((initial-path, initial-q, initial-qmap, 0),)
  let leaves = ()
  while pending.len() > 0 {
    let node = pending.pop()
    let path = node.at(0)
    let qcurves = node.at(1)
    let qmap = node.at(2)
    let depth = node.at(3)
    let lo = width-index(path.at(0))
    let hi = lo
    let total = 0.0
    for q in range(path.len()) {
      let w = width-index(path.at(q))
      lo = calc.min(lo, w)
      hi = calc.max(hi, w)
      if q + 1 < path.len() {
        total += _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
      }
    }
    if qcurves != none {
      let qbounds = source-q-bounds(qcurves)
      lo = qbounds.at(0)
      hi = qbounds.at(1)
    }
    let outer-min = if source-rounding { _mp-rounded(minw) } else { minw }
    // brushGenerate accepts any strictly interior cut; thinBrushGenerate
    // below has its separate 0.01 path-parameter endpoint guard.
    let crossing = split-path(path, outer-min, margin: 0.0,
      qcurves: qcurves, qmap: qmap)
    let recurse = hi > outer-min and lo < outer-min and depth < 10 and total > minlen and crossing != none
    if trace-nodes {
      nodes.push((stage: "outer", depth: depth, width-min: lo, width-max: hi,
        target: outer-min, length: total,
        path-start: frame-index(path.first()).at(0),
        path-end: frame-index(path.last()).at(0),
        cut-point: if crossing == none { none } else { crossing.at(8) },
        has-cut: crossing != none,
        cut-distance: if crossing == none { none } else { crossing.at(4) },
        cut-param: if crossing == none { none } else { crossing.at(7) },
        cut-debug: if crossing == none or qcurves == none { none }
          else { crossing.at(14) },
        q-curves-fixed: if qcurves == none { none } else { source-q-fixed(qcurves) },
        left-length: if crossing == none { 0.0 } else { crossing.at(2) },
        right-length: if crossing == none { 0.0 } else { crossing.at(3) },
        recurse: recurse))
    }
    if recurse {
      pending.push((crossing.at(1), crossing.at(10), crossing.at(12), depth + 1))
      pending.push((crossing.at(0), crossing.at(9), crossing.at(11), depth + 1))
    } else if lo > 0.99 * outer-min {
      leaves.push((path, 2, qcurves, qmap))
    } else if hi < 1.01 * outer-min {
      leaves.push((path, 1, qcurves, qmap))
    }
  }
  for leaf in leaves {
    let path = leaf.at(0)
    let qcurves = leaf.at(2)
    let qmap = leaf.at(3)
    outer-leaf-count += 1
    if leaf.at(1) == 2 {
      loops.push(band(path))
    } else {
      let thin-result = refine-thin(path, initial-q: qcurves, initial-qmap: qmap)
      nodes += thin-result.at(1)
      for thin-leaf in thin-result.at(0) {
        thin-leaf-count += 1
        if thin-leaf.at(1) >= minw {
          loops.push(band(thin-leaf.at(0), fixed: minw))
        } else {
          let result = dashband(thin-leaf.at(0), target-width: thin-leaf.at(1))
          loops += result.at(0)
          rng-cursor += result.at(1)
        }
      }
    }
  }
  if with-stats {
    (loops, rng-cursor, (outer: outer-leaf-count, thin: thin-leaf-count,
      dashes: rng-cursor / 2, nodes: nodes))
  } else if with-rng { (loops, rng-cursor) } else { loops }
}

#let _fill(loops, paint) = {
  let segs = ()
  for lp in loops {
    if lp == none { continue }
    if type(lp) == dictionary {
      // MetaPost stipples use round pens. Four cubic arcs preserve that shape
      // while keeping each dot compact in the PDF.
      let c = lp.at("center")
      let r = lp.at("diameter") / 2
      let h = 0.5522847498 * r
      let orientation = if lp.at("reverse", default: false) { -1 } else { 1 }
      let q(dx, dy) = _mm((c.at(0) + dx, c.at(1) + orientation * dy))
      segs.push(curve.move(q(r, 0)))
      segs.push(curve.cubic(q(r, h), q(h, r), q(0, r)))
      segs.push(curve.cubic(q(-h, r), q(-r, h), q(-r, 0)))
      segs.push(curve.cubic(q(-r, -h), q(-h, -r), q(0, -r)))
      segs.push(curve.cubic(q(h, -r), q(r, -h), q(r, 0)))
      segs.push(curve.close())
    } else {
      if lp.len() < 3 { continue }
      segs.push(curve.move(_mm(lp.at(0))))
      for p in lp.slice(1) { segs.push(curve.line(_mm(p))) }
      segs.push(curve.line(_mm(lp.at(0))))
    }
  }
  if segs.len() == 0 { none } else { curve(fill: paint, stroke: none, ..segs) }
}

// Sample a path by arc length so stipple density does not depend on its
// polygon resolution. `w / dot-size` controls the chance of placing a dot.
#let _dot-loop(p, diameter) = {
  (center: p, diameter: diameter)
}
#let _clip-dot-to-circle(dot, center, radius) = {
  let p = dot.at("center")
  let dot-radius = dot.at("diameter") / 2
  let radial = _unit(_sub(p, center))
  let distance = _dist(p, center)
  if distance + dot-radius <= radius { return dot }
  if distance - dot-radius >= radius or distance <= 1e-9 { return none }

  // Clip only the few boundary dots against the local tangent to the sphere.
  // At stipple scale the tangent error is negligible, and this retains the
  // partial round marks that source clipping leaves at the silhouette.
  let sides = 24
  let circle = range(sides).map(i => {
    let a = 360 * i / sides
    _add(p, (dot-radius * _cos(a), dot-radius * _sin(a)))
  })
  let signed(q) = radius - _dot(_sub(q, center), radial)
  let out = ()
  let prev = circle.last()
  let prev-side = signed(prev)
  for curr in circle {
    let curr-side = signed(curr)
    if (prev-side >= 0) != (curr-side >= 0) {
      let t = prev-side / (prev-side - curr-side)
      out.push(_add(prev, _mul(_sub(curr, prev), t)))
    }
    if curr-side >= 0 { out.push(curr) }
    prev = curr
    prev-side = curr-side
  }
  if out.len() >= 3 { out } else { none }
}
#let _clip-dot-to-planes(dot, planes) = {
  if planes.len() == 0 { return dot }
  let center = dot.at("center")
  let radius = dot.at("diameter") / 2
  let fully-outside = planes.any(plane => {
    let signed = _dot(_sub(center, plane.at(0)), plane.at(1))
    signed - radius * _len(plane.at(1)) >= 0
  })
  if fully-outside { return none }
  let crosses-edge = planes.any(plane => {
    let signed = _dot(_sub(center, plane.at(0)), plane.at(1))
    signed + radius * _len(plane.at(1)) > 0
  })
  if not crosses-edge { return dot }
  let sides = 24
  let circle = range(sides).map(i => {
    let a = 360 * i / sides
    _add(center, (radius * _cos(a), radius * _sin(a)))
  })
  let clip-plane(poly, plane) = {
    if poly.len() == 0 { return () }
    let origin = plane.at(0)
    let outward = plane.at(1)
    let signed(p) = _dot(_sub(p, origin), outward)
    let clipped = ()
    let prev = poly.last()
    let prev-side = signed(prev)
    for curr in poly {
      let curr-side = signed(curr)
      if (prev-side <= 0) != (curr-side <= 0) {
        let t = prev-side / (prev-side - curr-side)
        clipped.push(_add(prev, _mul(_sub(curr, prev), t)))
      }
      if curr-side <= 0 { clipped.push(curr) }
      prev = curr
      prev-side = curr-side
    }
    clipped
  }
  let poly = planes.fold(circle, (poly, plane) => clip-plane(poly, plane))
  if poly.len() < 3 { return none }
  poly
}
#let _inside-poly(p, poly) = {
  if poly.len() < 3 { return false }
  let inside = false
  let prev = poly.last()
  for curr in poly {
    let y0 = prev.at(1)
    let y1 = curr.at(1)
    if (y0 > p.at(1)) != (y1 > p.at(1)) {
      let x = prev.at(0) + (p.at(1) - y0) * (curr.at(0) - prev.at(0)) / (y1 - y0)
      if p.at(0) < x { inside = not inside }
    }
    prev = curr
  }
  inside
}
#let _inside-poly-indexed(p, polygon, index) = {
  if polygon.len() < 3 or p.at(1) < index.min-y or p.at(1) > index.max-y {
    return false
  }
  let grid-size = index.grid-size
  let edge-grid = index.edge-grid
  let x-cell = if index.max-x > index.min-x {
    int(calc.clamp(calc.floor((p.at(0) - index.min-x) /
      (index.max-x - index.min-x) * grid-size), 0, grid-size - 1))
  } else { 0 }
  let y-cell = if index.max-y > index.min-y {
    int(calc.clamp(calc.floor((p.at(1) - index.min-y) /
      (index.max-y - index.min-y) * grid-size), 0, grid-size - 1))
  } else { 0 }
  // The ray test only needs edges at this height and to the right of p.
  let candidates = ()
  for ix in range(x-cell, grid-size) {
    for j in edge-grid.at(y-cell).at(ix) {
      if not candidates.contains(j) { candidates.push(j) }
    }
  }
  let inside = false
  for j in candidates {
    let prev = polygon.at(j)
    let curr = polygon.at(_mod(j + 1, polygon.len()))
    let y0 = prev.at(1)
    let y1 = curr.at(1)
    if (y0 > p.at(1)) != (y1 > p.at(1)) {
      let x = prev.at(0) + ((p.at(1) - y0) *
        (curr.at(0) - prev.at(0)) / (y1 - y0))
      if p.at(0) < x { inside = not inside }
    }
  }
  inside
}
#let _shadowed-by-polygon(point, vertices, light) = {
  if vertices.len() < 3 { return false }
  let a = vertices.at(0)
  let b = vertices.at(1)
  let c = vertices.at(2)
  let ab = (b.at(0) - a.at(0), b.at(1) - a.at(1), b.at(2) - a.at(2))
  let ac = (c.at(0) - a.at(0), c.at(1) - a.at(1), c.at(2) - a.at(2))
  let normal = (ab.at(1) * ac.at(2) - ab.at(2) * ac.at(1),
                ab.at(2) * ac.at(0) - ab.at(0) * ac.at(2),
                ab.at(0) * ac.at(1) - ab.at(1) * ac.at(0))
  let denom = normal.at(0) * light.at(0) + normal.at(1) * light.at(1) + normal.at(2) * light.at(2)
  if calc.abs(denom) < 1e-9 { return false }
  let delta = (a.at(0) - point.at(0), a.at(1) - point.at(1), a.at(2) - point.at(2))
  let t = (normal.at(0) * delta.at(0) + normal.at(1) * delta.at(1) + normal.at(2) * delta.at(2)) / denom
  if t <= 0 { return false }
  let hit = (point.at(0) + t * light.at(0),
             point.at(1) + t * light.at(1),
             point.at(2) + t * light.at(2))
  // Dropping the normal's largest component gives a stable 2D projection.
  let ax = calc.abs(normal.at(0))
  let ay = calc.abs(normal.at(1))
  let az = calc.abs(normal.at(2))
  let drop = if ax >= ay and ax >= az { 0 } else if ay >= az { 1 } else { 2 }
  let project(p) = if drop == 0 { (p.at(1), p.at(2)) }
                   else if drop == 1 { (p.at(0), p.at(2)) }
                   else { (p.at(0), p.at(1)) }
  _inside-poly(project(hit), vertices.map(project))
}
#let _shadowed(p, regions, center, depth: 0, plane-depth: none,
               light: (-0.353553, 0.382683, 0.853553), shadow-planes: (), shadow-polygons: ()) = {
  let local = _sub(p, center)
  let explicit = regions.any(poly => _inside-poly(local, poly))
  // MetaPost's shadowDepth uses the sphere's frontmost pole as z = 0, while
  // the 3D polygon API below uses the sphere center as its origin.
  let plane-z = if plane-depth == none { depth } else { plane-depth }
  let projected = shadow-planes.any(shadow => {
    let dz = shadow.depth - plane-z
    // Match Fiziko's XY shadow-path projection: offsets scale by the
    // light's z component. A plane occludes only points behind it.
    // Shadow polygon coordinates use world XY (y up); drawing points use
    // screen XY (y down).
    if calc.abs(light.at(2)) < 0.000001 or dz * light.at(2) <= 0 { false }
    else {
      let t = dz * light.at(2)
      _inside-poly((local.at(0) + light.at(0) * t,
                    -local.at(1) + light.at(1) * t), shadow.polygon)
    }
  })
  let spatial = shadow-polygons.any(shadow =>
    _shadowed-by-polygon((local.at(0), -local.at(1), depth), shadow.vertices, light))
  explicit or projected or spatial
}

/// A source-style planar occluder. `polygon` uses sphere-local XY coordinates
/// with y up; `depth` is measured from the frontmost sphere pole and increases
/// toward the light, matching MetaPost's `shadowDepth` projection.
#let sphere-shadow-plane(polygon, depth) = (polygon: polygon, depth: depth)
/// A planar 3D occluder. Vertices are (x, y, z) in sphere-local coordinates;
/// the polygon must be simple and planar. Its plane may have any orientation.
#let sphere-shadow-polygon(vertices) = (vertices: vertices)
#let _stipple-loops(fr, ws, closed, step, dot-size, seed,
                    normal-jitter: 0.45, ink-space: false,
                    independent-spacing: false,
                    density: 1.0,
                    clip-dot: none, path-fractions: none) = {
  let n = fr.len()
  if n < 2 or step <= 0 or dot-size <= 0 { return () }
  let count = if closed { n } else { n - 1 }
  let cum = (0.0,)
  for i in range(count) {
    cum.push(cum.last() + _dist(fr.at(i).at(0), fr.at(calc.rem(i + 1, n)).at(0)))
  }
  let total = cum.last()
  if ink-space {
    // `thinBrushGenerate.stipples` sets dot count from integrated ink. For
    // constant width this is floor(width × length / dot-size²), with one
    // Bernoulli dot when the expected count is below one.
    let mass-cum = (0.0,)
    let total-mass = 0.0
    for i in range(count) {
      let j = calc.rem(i + 1, n)
      let length = cum.at(i + 1) - cum.at(i)
      let mass = density * length * (ws.at(i) + ws.at(j)) / (2 * dot-size * step)
      total-mass += calc.max(0.0, mass)
      mass-cum.push(total-mass)
    }
    let full-slots = int(calc.floor(total-mass))
    let tail-dot = full-slots == 0 and _rng(seed, 1, 9) < total-mass
    let slots = full-slots + if tail-dot { 1 } else { 0 }
    if slots <= 0 { return () }
    let loops = ()
    let seg = 0
    let offset-a = _rng(seed, 1, 1)
    let offset-b = if full-slots >= 3 { _rng(seed, 1, 2) } else { offset-a }
    for k in range(slots) {
      let mass-pos = if full-slots == 0 {
        _rng(seed, 1, 1) * total-mass
      } else if full-slots < 3 {
        // With one or two dots, stipplesBrushPattern randomizes only the
        // first offset; each following dot lands on the next full d0 step.
        (if k == 0 { offset-a } else { float(k) }) * total-mass / full-slots
      } else {
        // Brush dash patterns reuse two random offsets. Surface lanes restart
        // their pattern at width-driven splits, so independently keyed offsets
        // avoid long coherent rows without building recursive path fragments.
        let offset = if independent-spacing { _rng(seed, k, 17) }
                     else if calc.rem(k, 2) == 1 { offset-b } else { offset-a }
        (k + offset) * total-mass / full-slots
      }
      while seg + 1 < count and mass-cum.at(seg + 1) < mass-pos { seg += 1 }
      let segment-mass = mass-cum.at(seg + 1) - mass-cum.at(seg)
      if segment-mass <= 0 { continue }
      let t = calc.clamp((mass-pos - mass-cum.at(seg)) / segment-mass, 0.0, 1.0)
      let j = calc.rem(seg + 1, n)
      let a = fr.at(seg).at(0)
      let b = fr.at(j).at(0)
      let p = _add(_mul(a, 1 - t), _mul(b, t))
      let normal = _normal(_sub(b, a))
      let offset = (2 * _rng(seed, k, 3) - 1) * dot-size * normal-jitter
      let dot = _dot-loop(_add(p, _mul(normal, offset)), dot-size)
      let path-t = if path-fractions == none { (seg + t) / count }
                   else { path-fractions.at(seg) * (1 - t) + path-fractions.at(j) * t }
      let clipped = if clip-dot == none { dot } else { clip-dot(dot, path-t) }
      if clipped != none { loops.push(clipped) }
    }
    return loops
  }
  let slots = int(calc.floor(total / step))
  let loops = ()
  let seg = 0
  for k in range(slots) {
    let key = k * k * 7919 + k * 104729
    let s = (k + 0.5 + 0.32 * (2 * _rng(seed, key, 1) - 1)) * step
    while seg + 1 < count and cum.at(seg + 1) < s { seg += 1 }
    let j = calc.rem(seg + 1, n)
    let length = cum.at(seg + 1) - cum.at(seg)
    if length <= 0 { continue }
    let t = calc.clamp((s - cum.at(seg)) / length, 0.0, 1.0)
    let width = ws.at(seg) * (1 - t) + ws.at(j) * t
    if _rng(seed, key, 2) >= calc.clamp(width / dot-size, 0.0, 1.0) { continue }
    let a = fr.at(seg).at(0)
    let b = fr.at(j).at(0)
    let normal = _normal(_sub(b, a))
    let p = _add(_add(_mul(a, 1 - t), _mul(b, t)),
      _mul(normal, (2 * _rng(seed, key, 3) - 1) * dot-size * normal-jitter))
    let dot = _dot-loop(p, dot-size)
    let path-t = if path-fractions == none { (seg + t) / count }
                 else { path-fractions.at(seg) * (1 - t) + path-fractions.at(j) * t }
    let clipped = if clip-dot == none { dot } else { clip-dot(dot, path-t) }
    if clipped != none { loops.push(clipped) }
  }
  loops
}

// ---------------------------------------------------------------------------
// public primitives
// ---------------------------------------------------------------------------

/// Offset curve: points at distance f(t) along the left-hand normal in
/// mathematical (y-up) coordinates, where t is normalized arc length.
/// This matches MetaPost's offsetPath orientation in the screen-space API.
#let offset-path(pts, f, closed: true, per: 12, shift: (0, 0)) = {
  let src = pts.map(p => _add(p, shift))
  let fr = _frame(_prepare(src, per, closed), closed)
  let n = fr.len()
  let ts = _path-fractions(fr.map(e => e.at(0)), closed)
  fr.enumerate().map(((i, e)) => {
    let t = ts.at(i)
    _add(e.at(0), _mul(e.at(1), -_val(f, t)))
  })
}

/// Plain stroked path (dash: use Typst stroke dash patterns).
#let stroke-path(pts, stroke: 0.5pt + black, closed: false, per: 12, shift: (0, 0)) = {
  let src = _prepare(pts.map(p => _add(p, shift)), per, closed)
  let segs = (curve.move(_mm(src.at(0))),)
  for p in src.slice(1) { segs.push(curve.line(_mm(p))) }
  if closed { segs.push(curve.line(_mm(src.at(0)))) }
  place(top + left, curve(fill: none, stroke: stroke, ..segs))
}

/// Variable-width stroke ("brush"): band of width w(t) about the curve,
/// optionally displaced by offset(t); both functions use normalized arc
/// length unless `_path-time` requests uniform path time on open paths.
/// Ink-conserving below `min-w`;
/// `seed` controls deterministic dash-length variation and phase (default 0).
#let stroke-ink(pts, w, offset: 0, closed: true, per: 12,
                min-w: _source-min-stroke, period: _source-dash-length, seed: 0,
                shift: (0, 0), fill: black,
                _random-stream: none, _rng-offset: 0, _with-rng: false,
                _source-rounding: false, _with-stats: false,
                _trace-nodes: false, _path-time: false,
                _param-times: none, _param-end: none,
                _source-width-fixed: none,
                _source-q-curves-fixed: none,
                _source-arc-positions: none) = {
  let src = pts.map(p => _add(p, shift))
  let fr0 = _frame(_prepare(src, per, closed), closed)
  let n = fr0.len()
  let ts = if _path-time and not closed {
    range(n).map(i => if n > 1 { i / (n - 1) } else { 0.0 })
  } else { _path-fractions(fr0.map(e => e.at(0)), closed) }
  let fr = fr0.enumerate().map(((i, e)) => {
    let t = ts.at(i)
    (_add(e.at(0), _mul(e.at(1), _val(offset, t))), e.at(1))
  })
  let ws = range(n).map(i => {
    _val(w, ts.at(i))
  })
  let ink = _ink-loops(fr, ws, closed, min-w, period,
    seed: seed, dash-extra: _source-brush-width-guard, dash-cap: 1,
    random-stream: _random-stream, rng-offset: _rng-offset,
    with-rng: _with-rng, with-stats: _with-stats,
    trace-nodes: _trace-nodes, source-rounding: _source-rounding,
    param-times: _param-times, param-end: _param-end,
    source-width-fixed: _source-width-fixed,
    source-q-curves-fixed: _source-q-curves-fixed,
    source-arc-positions: _source-arc-positions)
  let drawing = place(top + left,
    _fill(if _with-rng or _with-stats { ink.at(0) } else { ink }, fill))
  if _with-stats {
    (drawing, ink.at(1), ink.at(2),
      (times: ts, points: fr.map(e => e.at(0)), widths: ws))
  }
  else if _with-rng { (drawing, ink.at(1)) } else { drawing }
}

/// Deterministic stippled stroke. `w(t)` is the local density in mm;
/// `dot-size` and `step` control individual dots and spacing independently;
/// `density` scales the ink-based dot count.
#let stroke-stipple(pts, w, offset: 0, closed: true, per: 12,
                    dot-size: _source-max-shading, step: 2.5 * _source-max-shading,
                    seed: 0, normal-jitter: 0.45, ink-space: false,
                    independent-spacing: false,
                    density: 1.0,
                    shift: (0, 0), fill: black, _clip-dot: none) = {
  let src = pts.map(p => _add(p, shift))
  let fr0 = _frame(_prepare(src, per, closed), closed)
  let n = fr0.len()
  let ts = _path-fractions(fr0.map(e => e.at(0)), closed)
  let fr = fr0.enumerate().map(((i, e)) => {
    let t = ts.at(i)
    (_add(e.at(0), _mul(e.at(1), _val(offset, t))), e.at(1))
  })
  let ws = range(n).map(i => _val(w, ts.at(i)))
  place(top + left, _fill(_stipple-loops(fr, ws, closed, step, dot-size, seed,
    normal-jitter: normal-jitter, ink-space: ink-space,
    independent-spacing: independent-spacing, density: density,
    clip-dot: _clip-dot,
    path-fractions: ts), fill))
}

// Open stipple-brush paths use the source's quantized, width-driven recursion.
#let _brush-leaf-stipple(pts, w, offset, per, dot-size, track-spacing,
                         dot-range, density, seed, shift, fill) = {
  let src = pts.map(p => _add(p, shift))
  let base = _frame(_prepare(src, per, false), false)
  let n = base.len()
  if n < 2 { return none }
  let ts = _path-fractions(base.map(e => e.at(0)), false)
  let fr = base.enumerate().map(((i, e)) =>
    (_add(e.at(0), _mul(e.at(1), _val(offset, ts.at(i)))), e.at(1)))
  let ws = ts.map(t => _val(w, t))
  let cum = (0.0,)
  for i in range(n - 1) {
    cum.push(cum.last() + _dist(fr.at(i).at(0), fr.at(i + 1).at(0)))
  }
  let total = cum.last()
  if total <= 0 { return none }
  let find-seg(s) = {
    let lo = 0
    let hi = n - 1
    while hi - lo > 1 {
      let mid = int(calc.floor((lo + hi) / 2))
      if cum.at(mid) <= s { lo = mid } else { hi = mid }
    }
    lo
  }
  let frame-at(s) = {
    let seg = find-seg(s)
    let span = cum.at(seg + 1) - cum.at(seg)
    let f = if span > 0 { calc.clamp((s - cum.at(seg)) / span, 0.0, 1.0) } else { 0.0 }
    let a = fr.at(seg)
    let b = fr.at(seg + 1)
    (_add(a.at(0), _mul(_sub(b.at(0), a.at(0)), f)),
     _unit(_add(a.at(1), _mul(_sub(b.at(1), a.at(1)), f))))
  }
  let width-at(s) = {
    let seg = find-seg(s)
    let span = cum.at(seg + 1) - cum.at(seg)
    let f = if span > 0 { calc.clamp((s - cum.at(seg)) / span, 0.0, 1.0) } else { 0.0 }
    ws.at(seg) * (1 - f) + ws.at(seg + 1) * f
  }

  let min-leaf = dot-size * _source-min-stipple-width-ratio
  let width-step = _source-dash-width-step
  let tolerance = 0.01 * pt
  let min-leaf-length = dot-size / 2
  // A stack preserves the source's depth-first, left-before-right leaf order.
  let pending = ((0.0, total, 0),)
  let leaves = ()
  while pending.len() > 0 {
    let node = pending.last()
    pending = pending.slice(0, pending.len() - 1)
    let s0 = node.at(0)
    let s1 = node.at(1)
    let depth = node.at(2)
    let seg0 = find-seg(s0)
    let seg1 = find-seg(s1)
    let lo = calc.min(width-at(s0), width-at(s1))
    let hi = calc.max(width-at(s0), width-at(s1))
    for i in range(seg0 + 1, seg1 + 1) {
      lo = calc.min(lo, ws.at(i))
      hi = calc.max(hi, ws.at(i))
    }
    let target = if lo > min-leaf - tolerance {
      min-leaf + calc.floor(calc.max(0.0, ((hi + lo) / 2 - min-leaf) / width-step)) * width-step
    } else { min-leaf }
    let crossings = ()
    for i in range(seg0, seg1 + 1) {
      let a = calc.max(s0, cum.at(i))
      let b = calc.min(s1, cum.at(i + 1))
      if b <= a { continue }
      let span = cum.at(i + 1) - cum.at(i)
      let fa = (a - cum.at(i)) / span
      let fb = (b - cum.at(i)) / span
      let wa = ws.at(i) * (1 - fa) + ws.at(i + 1) * fa
      let wb = ws.at(i) * (1 - fb) + ws.at(i + 1) * fb
      if wa != wb and (wa - target) * (wb - target) <= 0 {
        let cut = a + (target - wa) / (wb - wa) * (b - a)
        let fraction = (cut - s0) / (s1 - s0)
        if fraction > 0.005 and fraction < 0.995 { crossings.push(cut) }
      }
    }
    let cut = if crossings.len() > 0 { crossings.first() } else { none }
    let split = cut != none and hi - lo >= width-step and depth < 15 and ((cut - s0) > min-leaf-length or (s1 - cut) > min-leaf-length)
    if split {
      pending.push((cut, s1, depth + 1))
      pending.push((s0, cut, depth + 1))
    } else {
      leaves.push((s0, s1, target))
    }
  }

  let loops = ()
  let tiny = 0.001 * dot-size
  for (idx, leaf) in leaves.enumerate() {
    let s0 = leaf.at(0)
    let s1 = leaf.at(1)
    let len = s1 - s0
    if len <= min-leaf-length { continue }
    let qwidth = leaf.at(2)
    if qwidth / 3 < min-leaf { continue }
    for lane in range(3) {
      let side = lane - 1
      let key = (idx + 1) * 104729 + lane * 13007
      let size = dot-size * (dot-range.at(0) + (dot-range.at(1) - dot-range.at(0)) * _rng(seed, key, 11))
      let expected = density * (qwidth / 3) * len / (size * size)
      let whole = int(calc.floor(expected))
      let dots = ()
      if whole > 0 {
        let spacing = len / whole
        let first = _rng(seed, key, 1) * spacing
        if whole >= 3 {
          let second = _rng(seed, key, 2) * spacing
          let j = 0
          while first + 2 * j * spacing < len {
            let d = first + 2 * j * spacing
            if d < len - tiny { dots.push(d) }
            let e = spacing + second + 2 * j * spacing
            if e < len - tiny { dots.push(e) }
            j += 1
          }
        } else {
          let j = 0
          while first + j * spacing < len - tiny {
            dots.push(first + j * spacing)
            j += 1
          }
        }
      } else if _rng(seed, key, 3) < expected {
        dots.push(_rng(seed, key, 4) * calc.max(0.0, len - tiny))
      }
      for d in dots {
        let f = frame-at(s0 + d)
        let center = _add(f.at(0), _mul(f.at(1), side * track-spacing / 3))
        loops.push(_dot-loop(center, size))
      }
    }
  }
  _fill(loops, fill)
}

/// Three-track stippled brush. `w(t)` is the total ink-width profile; it is
/// split across three tracks as in `thinBrush.stipples`. Open paths use
/// quantized, width-driven pattern restarts; closed paths keep a continuous
/// ring distribution. `density` adjusts the expected dots per local pattern.
#let stroke-stipple-brush(pts, w, offset: 0, closed: false, per: 12,
                          dot-size: _source-max-shading,
                          track-spacing: 1.5 * _source-max-shading,
                          dot-range: (0.9, 1.2),
                          density: 0.5,
                          seed: 0, shift: (0, 0), fill: black) = {
  if not closed {
    // Like every canvas primitive, keep the raw fill out of document flow.
    // Otherwise a second open brush starts below the first brush's bounds.
    place(top + left, _brush-leaf-stipple(pts, w, offset, per, dot-size, track-spacing,
      dot-range, density, seed, shift, fill))
  } else {
    let marks = ()
    for lane in range(3) {
      let side = lane - 1
      let key = lane * 104729
      let size-scale = dot-range.at(0) + (dot-range.at(1) - dot-range.at(0)) * _rng(seed, key, 11)
      let lane-dot-size = dot-size * size-scale
      marks.push(stroke-stipple(pts,
        t => {
          let lane-width = _val(w, t) / 3
          if lane-width >= dot-size * _source-min-stipple-width-ratio { lane-width } else { 0.0 }
        },
        offset: t => _val(offset, t) + side * track-spacing / 3,
        closed: true, per: per, dot-size: lane-dot-size, step: lane-dot-size,
        seed: seed + lane * 104729, normal-jitter: 0, ink-space: true,
        density: density, shift: shift, fill: fill))
    }
    _join(marks)
  }
}

/// Sphere as concentric rings whose thickness follows a Lambert light model.
/// `light` is a 3D direction (x right, y up, z towards the viewer).
#let sphere(d, light: (-0.353553, 0.382683, 0.853553), rings: auto, samples: 128,
            max-w: _source-max-shading, gamma: 1.0,
            min-w: _source-min-stroke, period: _source-dash-length,
            seed: 0, center: (0, 0), shadow-regions: (), shadow-planes: (), shadow-polygons: (), fill: black) = {
  let R = d / 2
  // fiziko chooses a power-of-two ring count so the radial gap stays near its
  // shading density (3 × the maximum hatch width).
  let ring-count = if rings == auto {
    calc.max(1, int(calc.pow(2, calc.ceil(calc.log(R / (3 * max-w), base: 2)))))
  } else { rings }
  let ln = calc.sqrt(
    light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2),
  )
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  let loops = ()
  // Independent seeded phases keep ring placement stable when path sampling
  // changes; MetaPost instead interleaves phases with global dash randomness.
  let rng-cursor = 0
  for k in range(1, ring-count + 1) {
    // `sphere.c` thins every other ring to account for the residual between
    // the chosen power-of-two ring count and the requested diameter. Its
    // residual is a MetaPost bp scalar, so convert the mm value before using
    // it as a multiplier in Typst's mm coordinates.
    let ring-max = if calc.rem(k, 2) == 1 {
      max-w * calc.abs(d - (3 * max-w * ring-count)) / (ring-count * _mp-unit)
    } else { max-w }
    // The source puts the last ring on the silhouette and clips its centered
    // brush band to the disk. Recenter the retained inner half-band here so
    // it meets the same circular boundary without polygon boolean clipping.
    let r = R * k / ring-count
    // `sphere.c` rotates each ring by a small random angle before drawing it.
    let phase-key = k * k * 7919 + k * 104729
    // Angles below use plain degrees, so convert MetaPost's 0..π/4 phase.
    // MetaPost's `rotated (1/4 pi)` uses degree-valued angles, so this is
    // only about 0.785°, not 45°.
    let phase = (calc.pi / 4) * _rng(seed, phase-key, 1)
    let pts = range(samples).map(j => {
      let a = 360 * j / samples + phase
      _add(center, (r * _cos(a), r * _sin(a)))
    })
    let base-fr = _frame(pts, true)
    // MetaPost's offsetPathTemplate samples width at the eight fullcircle
    // segment knots, then joins those values linearly. Preserve dense ring
    // geometry while using that same coarse width template.
    let knot-lightness = range(8).map(i => {
      let a = phase + 45 * i
      let p = _add(center, (r * _cos(a), r * _sin(a)))
      let z = calc.sqrt(calc.max(0.0, R * R - r * r))
      let nx = (p.at(0) - center.at(0)) / R
      let ny = -(p.at(1) - center.at(1)) / R   // screen y is down
      let nz = z / R
      let lam = calc.clamp(
        nx * L.at(0) + ny * L.at(1) + nz * L.at(2), 0.0, 1.0)
      if _shadowed(p, shadow-regions, center, depth: z, plane-depth: z - R, light: L,
                   shadow-planes: shadow-planes, shadow-polygons: shadow-polygons) { 1.0 }
      else { calc.pow(1 - lam, gamma) }
    })
    let widths = range(samples).map(j => {
      let u = 8 * j / samples
      let i = int(calc.floor(u))
      let f = u - i
      let next = _mod(i + 1, 8)
      let p = base-fr.at(j).at(0)
      let z = calc.sqrt(calc.max(0.0, R * R - r * r))
      let is-shadowed = _shadowed(p, shadow-regions, center, depth: z, plane-depth: z - R, light: L,
        shadow-planes: shadow-planes, shadow-polygons: shadow-polygons)
      let lightness = knot-lightness.at(i) * (1 - f) + knot-lightness.at(next) * f
      if is-shadowed { ring-max } else { ring-max * lightness }
    })
    let fr = if k == ring-count {
      let inner-points = base-fr.enumerate().map(((i, e)) => {
        let radial = _unit(_sub(e.at(0), center))
        _sub(e.at(0), _mul(radial, widths.at(i) / 4))
      })
      _frame(inner-points, true)
    } else { base-fr }
    let ws = if k == ring-count { widths.map(w => w / 2) } else { widths }
    let (ring-loops, consumed) = _ink-loops(
      fr, ws, true, min-w, period, seed: seed + rng-cursor,
      dash-extra: _source-brush-width-guard,
      dash-cap: 1, with-rng: true,
    )
    loops += ring-loops
    rng-cursor += consumed
  }
  let shading = _fill(loops, fill)
  let rim-pts = range(samples).map(j => {
    let a = 360 * j / samples
    _add(center, (R * _cos(a), R * _sin(a)))
  })
  let rim = stroke-path(rim-pts,
    stroke: min-w * 1mm + fill, closed: true, per: 0)
  // MetaPost draws the outline first, then clips the ring shading over it.
  _join((rim, place(top + left, shading)))
}

/// Stippled sphere with a jittered two-dimensional point field and Lambert
/// lighting. Dot spacing controls the field resolution and expected density.
#let sphere-stipple(d, light: (-0.353553, 0.382683, 0.853553),
                    dot-step: 0.18, dot-size: 0.4 * pt,
                    gamma: 1.0, seed: 0,
                    center: (0, 0), shadow-regions: (), shadow-planes: (), shadow-polygons: (), fill: black) = {
  let R = d / 2
  let limit = calc.max(0.0, R - dot-size / 2)
  let row-step = dot-step * calc.sqrt(3) / 2
  let rows = int(calc.floor(2 * limit / row-step))
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  let loops = ()
  for row in range(rows + 1) {
    let y = -limit + row * row-step
    let shift = if calc.rem(row, 2) == 0 { 0.0 } else { dot-step / 2 }
    let cols = int(calc.floor((2 * limit - shift) / dot-step))
    for col in range(cols + 1) {
      let key = row * 1009 + col * 7919
      let x = -limit + shift + col * dot-step
      let p = _add(center, (
        x + (2 * _rng(seed, key * key + 1, 1) - 1) * dot-step * 0.42,
        y + (2 * _rng(seed, key * key + 1, 2) - 1) * dot-step * 0.42,
      ))
      let nx = (p.at(0) - center.at(0)) / R
      let ny = -(p.at(1) - center.at(1)) / R
      let radius2 = nx * nx + ny * ny
      if radius2 > limit * limit / (R * R) { continue }
      let nz = calc.sqrt(calc.max(0.0, 1 - radius2))
      let lam = calc.clamp(
        nx * L.at(0) + ny * L.at(1) + nz * L.at(2), 0.0, 1.0)
      let depth = R * nz
      let dark = if _shadowed(p, shadow-regions, center, depth: depth, plane-depth: depth - R, light: L,
                              shadow-planes: shadow-planes, shadow-polygons: shadow-polygons) { 1.0 }
                 else { calc.pow(1 - lam, gamma) }
      if _rng(seed, key * key + 1, 3) < dark { loops.push(_dot-loop(p, dot-size)) }
    }
  }
  place(top + left, _fill(loops, fill))
}

/// Stippled sphere drawn as dots along concentric rings, like `sphere.s`.
/// `density` scales dot count to account for the source's segmented dash
/// patterns; the default is calibrated against its S101 specimen.
/// The ordinary `sphere-stipple` remains a jittered two-dimensional field.
#let sphere-stipple-rings(d, light: (-0.353553, 0.382683, 0.853553),
                          samples: 128, dot-size: _source-stipple-size,
                          dot-range: (0.9, 1.2), gamma: 1.0, seed: 0, center: (0, 0),
                          density: 0.55,
                          shadow-regions: (), shadow-planes: (), shadow-polygons: (),
                          fill: black) = {
  let R = d / 2
  // sphere.s uses a denser radial pitch than sphere.c: its stipple shading
  // density is three half-dot steps (1.5 × stippleSize), not 3 × max-w.
  let spacing = dot-size * _source-stipple-spacing-ratio
  let ring-count = calc.max(1, int(calc.pow(2,
    calc.ceil(calc.log(R / spacing, base: 2)))))
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  let loops = ()
  for k in range(1, ring-count + 1) {
    let ring-max = if calc.rem(k, 2) == 1 {
      (_source-max-shading * calc.abs(d - (spacing * ring-count))) / (ring-count * _mp-unit)
    } else { _source-max-shading }
    let phase-key = k * k * 7919 + k * 104729
    // MetaPost's `rotated (1/4 pi)` receives degree-valued angles, so the
    // source phase spans only about 0.785 degrees rather than 45 degrees.
    let phase = (calc.pi / 4) * _rng(seed, phase-key, 1)
    let radius = R * k / ring-count
    // sphere.s places three dotted lanes across the width represented by each
    // concentric contour; outer lanes are omitted when their dots leave the
    // visible disk rather than drawing outside its silhouette.
    for lane in range(3) {
      let size-key = k * 7919 + lane * 104729
      let size-scale = dot-range.at(0) + (dot-range.at(1) - dot-range.at(0)) * _rng(seed, size-key, 11)
      let lane-dot-size = dot-size * size-scale
      let lane-radius = radius + (lane - 1) * d / (3 * ring-count)
      if lane-radius <= 0 { continue }
      let pts = range(samples).map(j => {
        let a = 360 * j / samples + phase
        _add(center, (lane-radius * _cos(a), lane-radius * _sin(a)))
      })
      let fr = _frame(pts, true)
      let ws = fr.map(e => {
        let p = e.at(0)
        let nx = (p.at(0) - center.at(0)) / R
        let ny = -(p.at(1) - center.at(1)) / R
        let nz = calc.sqrt(calc.max(0.0, 1 - nx * nx - ny * ny))
        let lam = calc.clamp(nx * L.at(0) + ny * L.at(1) + nz * L.at(2), 0.0, 1.0)
        let depth = R * nz
        let dark = if _shadowed(p, shadow-regions, center, depth: depth, plane-depth: depth - R, light: L,
                                shadow-planes: shadow-planes, shadow-polygons: shadow-polygons) { 1.0 }
                   else { calc.pow(1 - lam, gamma) }
        let lane-width = ring-max * dark / 3
        // thinBrushGenerate.stipples omits lanes below 1/20 of the dot pen.
        if lane-width >= dot-size * _source-min-stipple-width-ratio { lane-width } else { 0.0 }
      })
      let dots = _stipple-loops(fr, ws, true, lane-dot-size, lane-dot-size,
        seed + size-key, normal-jitter: 0, ink-space: true,
        independent-spacing: true, density: density)
      loops += dots.map(dot => _clip-dot-to-circle(dot, center, R))
    }
  }
  let rim-pts = range(samples).map(j => {
    let a = 360 * j / samples
    _add(center, (R * _cos(a), R * _sin(a)))
  })
  let rim = stroke-path(rim-pts, stroke: _source-min-stroke * 1mm + fill,
    closed: true, per: 0)
  _join((place(top + left, _fill(loops, fill)), rim))
}

/// Sphere shaded with the original fiziko-style latitudinal strokes.
/// `latitude` controls the projection of each parallel, while `spacing`
/// determines how many parallels are used for this diameter. The default
/// drawing resolution retains width-template knots while avoiding excessive
/// intermediate points; increase `samples` for unusually large output.
/// `rng: "metapost"` replays the default scaled MetaPost stream for brush dashes.
#let sphere-latitude(d, latitude: -60, light: (-0.353553, 0.382683, 0.853553),
                     max-w: _source-max-shading, spacing: _source-spacing, samples: 180,
                     gamma: 1.0, min-w: _source-min-stroke, period: _source-dash-length,
                     seed: 1, rng: "keyed", rng-offset: 0,
                     with-rng: false, with-trace: false,
                     surface-mask: none, mask-rotation: (0, 0),
                     trace-latitude: none, outline: true,
                     center: (0, 0), shadow-regions: (), shadow-planes: (), shadow-polygons: (), fill: black) = {
  assert(rng == "keyed" or rng == "metapost",
    message: "rng must be \"keyed\" or \"metapost\"")
  let R = d / 2
  let n = calc.max(2, calc.ceil(calc.pi * R / spacing))
  let slat = _sin(latitude)
  let clat = _cos(latitude)
  let tlat = if calc.abs(clat) > 0.000001 { slat / clat } else { 0.0 }
  let ln = calc.sqrt(
    light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2),
  )
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  let rng-cursor = rng-offset
  let random-stream = if rng == "metapost" {
    _metapost-rng-sequence(seed, rng-offset + 4 * n * samples)
  } else { none }
  let out = ()
  let trace = ()
  // MetaPost stores pi/n in 16.16 fixed point before multiplying by k.
  // Its accumulated angle is visible near the equator as tiny end segments.
  let phi-step = calc.round(calc.pi / n * 65536) / 65536 * 180 / calc.pi
  for k in range(1, n) {
    let phi = k * phi-step
    if phi + latitude <= 0 or phi + latitude >= 180 { continue }
    let sp = _sin(phi)
    let cp = _cos(phi)
    let ratio = if calc.abs(clat) > 0.000001 {
      tlat * cp / sp
    } else if (phi > 90 and latitude > 0) or (phi < 90 and latitude < 0) {
      -2.0
    } else { 2.0 }
    if ratio <= -1 { continue }
    let full = ratio > 1
    let edge = if full { 0deg } else { calc.asin(ratio) }
    // MetaPost's p0 is fullcircle rotated 90°. Partial parallels traverse its
    // cubic path backward from parameter 6 + edge/45° to 2 - edge/45°.
    let t-start = if full { 0.0 } else { 6 + edge / 45deg }
    let t-finish = if full { 8.0 } else { 2 - edge / 45deg }
    let rx = R * sp
    let count = if full { samples } else { samples + 1 }
    let pts = range(count).map(j => {
      let t = t-start + (t-finish - t-start) * j / samples
      let circle = _mp-circle-point(t)
      let x = 2 * rx * circle.at(0)
      let y = R * cp * clat + 2 * rx * circle.at(1) * slat
      _add(center, (x, -y))
    })
    let base-fr = _frame(pts, full)
    let path-s = (0.0,)
    let path-length = 0.0
    for i in range(pts.len()) {
      if full or i + 1 < pts.len() {
        let j = if i + 1 < pts.len() { i + 1 } else { 0 }
        path-length += _dist(pts.at(i), pts.at(j))
        path-s.push(path-length)
      }
    }
    let t-at(q) = t-start + (t-finish - t-start) * q
    let shadowed-at(t) = {
      let circle = _mp-circle-point(t)
      let local = (
        2 * rx * circle.at(0),
        -(R * cp * clat + 2 * rx * circle.at(1) * slat),
      )
      let radial = _len(local)
      let depth = calc.sqrt(calc.max(0.0, R * R - radial * radial))
      _shadowed(_add(center, local), shadow-regions, center,
        depth: depth, plane-depth: depth - R,
        light: L, shadow-planes: shadow-planes, shadow-polygons: shadow-polygons)
    }
    // offsetPathSubdivide cuts every original cubic into four. For partial
    // arcs, the first and last pieces are fractional cubic segments too.
    let boundaries = (t-start,)
    if full {
      boundaries = range(9).map(j => j * 1.0)
    } else {
      let cursor = calc.floor(t-start)
      while cursor > t-finish {
        if cursor < t-start { boundaries.push(cursor) }
        cursor -= 1
      }
      if boundaries.last() != t-finish { boundaries.push(t-finish) }
    }
    let knot-ts = (t-start,)
    for i in range(boundaries.len() - 1) {
      let a = boundaries.at(i)
      let b = boundaries.at(i + 1)
      for q in range(1, 5) { knot-ts.push(a + (b - a) * q / 4) }
    }
    // Shadow edges are discontinuities in the width template. Insert knots
    // at their crossings so interpolation cannot smear a whole hatch patch.
    if shadow-regions.len() > 0 or shadow-planes.len() > 0 {
      let shadow-cuts = ()
      let scan-count = calc.min(64, samples)
      for j in range(scan-count) {
        let q0 = j / scan-count
        let q1 = (j + 1) / scan-count
        let t0 = t-at(q0)
        let t1 = t-at(q1)
        let side = shadowed-at(t0)
        if side != shadowed-at(t1) {
          let lo = q0
          let hi = q1
          for _ in range(20) {
            let mid = (lo + hi) / 2
            if shadowed-at(t-at(mid)) == side { lo = mid } else { hi = mid }
          }
          shadow-cuts.push(t-at((lo + hi) / 2))
        }
      }
      if shadow-cuts.len() > 0 {
        let expanded = ()
        for i in range(knot-ts.len() - 1) {
          let a = knot-ts.at(i)
          let b = knot-ts.at(i + 1)
          let qa = (a - t-start) / (t-finish - t-start)
          let qb = (b - t-start) / (t-finish - t-start)
          expanded.push(a)
          for cut in shadow-cuts {
            let qc = (cut - t-start) / (t-finish - t-start)
            if qc > qa + 0.000000001 and qc < qb - 0.000000001 {
              expanded.push(cut)
            }
          }
        }
        expanded.push(knot-ts.last())
        knot-ts = expanded
      }
    }
    // offsetPathTemplate's x coordinate is arc length, so its piecewise
    // linear width function must be sampled against arc length as well.
    let knot-s = knot-ts.map(t => {
      let q = calc.clamp((t - t-start) / (t-finish - t-start) * samples, 0.0, samples)
      if full and q >= samples - 1 {
        let i = samples - 1
        let f = q - i
        path-s.at(i) + f * _dist(pts.at(i), pts.at(0))
      } else if q >= samples { path-length } else {
        let i = int(calc.floor(q))
        let f = q - i
        let j = i + 1
        path-s.at(i) + f * _dist(pts.at(i), pts.at(j))
      }
    })
    let knot-ws = knot-ts.map(t => {
      let circle = _mp-circle-point(t)
      let local-x = 2 * rx * circle.at(0)
      let local-y = -(R * cp * clat + 2 * rx * circle.at(1) * slat)
      let radius = calc.sqrt(local-x * local-x + local-y * local-y)
      let radial-normal = calc.min(0.999999, 2 * radius / (d + _mp-unit))
      let radial-scale = if radius > 0 { radial-normal / radius } else { 0.0 }
      let nx = local-x * radial-scale
      let ny = -local-y * radial-scale
      let nz = calc.sqrt(calc.max(0.0, 1 - radial-normal * radial-normal))
      let lam = calc.clamp(nx * L.at(0) + ny * L.at(1) + nz * L.at(2), 0.0, 1.0)
      let xn = calc.min(1.0, calc.abs(local-x / R))
      let yn = local-y / R
      let xfade = 1 - calc.pow(1 - xn, calc.abs(slat))
      let density = calc.sqrt(calc.max(0.0, 1 - calc.pow(yn, 2) - calc.pow(xfade, 2)))
      let depth = calc.sqrt(calc.max(0.0, R * R - radius * radius))
      // Recover geographic coordinates from the orthographic screen point.
      // `local-y` uses Typst's downward-positive drawing coordinates.
      let world-y = -local-y
      let mask-lat = calc.asin(calc.clamp(
        world-y / R * _cos(mask-rotation.at(1))
          + depth / R * _sin(mask-rotation.at(1)), -1.0, 1.0)) / 1deg
      // Invert globe-project's source-oriented axes to recover the longitude
      // used by the geographic land mask.
      let mask-lon = mask-rotation.at(0) + calc.atan2(
        local-x, world-y * _sin(mask-rotation.at(1))
          - depth * _cos(mask-rotation.at(1))) / 1deg
      let cast-shadow = _shadowed(_add(center, (local-x, local-y)),
        shadow-regions, center, depth: depth, plane-depth: depth - R, light: L, shadow-planes: shadow-planes,
        shadow-polygons: shadow-polygons)
      let lightness = if cast-shadow { 1.0 } else { calc.pow(1 - lam, gamma) }
      let in-mask = surface-mask == none or surface-mask(mask-lon, mask-lat)
      if in-mask { max-w * _lat-density(density, k) * lightness } else { 0.0 }
    })
    let ws = pts.enumerate().map(((i, _)) => {
      let s = path-s.at(i)
      let j = range(knot-s.len() - 1).find(j => knot-s.at(j) <= s and s <= knot-s.at(j + 1))
      let j = if j == none { knot-s.len() - 2 } else { j }
      let f = (s - knot-s.at(j)) / (knot-s.at(j + 1) - knot-s.at(j))
      knot-ws.at(j) * (1 - f) + knot-ws.at(j + 1) * f
    })
    // Keep each offsetPathTemplate knot in the recursive brush path. Width
    // extrema and threshold crossings can occur between drawing samples.
    let fr = ()
    let widths = ()
    let param-times = ()
    let param-time(s) = {
      let j = range(knot-s.len() - 1).find(j =>
        knot-s.at(j) <= s and s <= knot-s.at(j + 1))
      let j = if j == none { knot-s.len() - 2 } else { j }
      let span = knot-s.at(j + 1) - knot-s.at(j)
      j + if span > 0 { (s - knot-s.at(j)) / span } else { 0.0 }
    }
    let knot = 1
    for i in range(count) {
      fr.push(base-fr.at(i))
      widths.push(ws.at(i))
      let start-s = path-s.at(i)
      param-times.push(param-time(start-s))
      if i + 1 < path-s.len() {
        let end-s = path-s.at(i + 1)
        while knot < knot-s.len() - 1 and knot-s.at(knot) <= end-s + 0.000000001 {
          let at-s = knot-s.at(knot)
          if at-s > start-s + 0.000000001 and at-s < end-s - 0.000000001 {
            let t = knot-ts.at(knot)
            let circle = _mp-circle-point(t)
            let point = _add(center, (2 * rx * circle.at(0),
              -(R * cp * clat + 2 * rx * circle.at(1) * slat)))
            let next = if full { _mod(i + 1, count) } else { i + 1 }
            let f = (at-s - start-s) / (end-s - start-s)
            let normal = _unit(_add(_mul(base-fr.at(i).at(1), 1 - f),
              _mul(base-fr.at(next).at(1), f)))
            fr.push((point, normal))
            widths.push(knot-ws.at(knot))
            param-times.push(float(knot))
          }
          knot += 1
        }
      }
    }
    let ink = _ink-loops(
      fr, widths, full, min-w, period,
      seed: if rng == "metapost" { seed } else { seed + rng-cursor },
      random-stream: random-stream, rng-offset: rng-cursor,
      dash-extra: _source-brush-width-guard,
      dash-cap: 1,
      with-rng: true, with-stats: with-trace,
      param-times: param-times,
      param-end: float(knot-ts.len() - 1),
      trace-nodes: trace-latitude == k,
    )
    if with-trace {
      trace.push((latitude: k, path-length: path-length,
        width-min: calc.min(..knot-ws), width-max: calc.max(..knot-ws),
        knot-s: knot-s, knot-w: knot-ws,
        brush-nodes: fr.len(),
        outer-leaves: ink.at(2).outer, thin-leaves: ink.at(2).thin,
        dash-calls: ink.at(2).dashes, nodes: ink.at(2).nodes))
    }
    out += ink.at(0)
    rng-cursor += ink.at(1)
  }
  // Keep the silhouette independent of the latitude hatching.
  if outline {
    let rim = range(samples).map(j => {
      let a = 360 * j / samples
      _add(center, (R * _cos(a), R * _sin(a)))
    })
    let rfr = _frame(rim, true)
    let rws = range(rfr.len()).map(_ => min-w)
    out += _ink-loops(rfr, rws, true, min-w, period, seed: seed)
  }
  let drawing = place(top + left, _fill(out, fill))
  if with-trace { (drawing, rng-cursor, trace) }
  else if with-rng { (drawing, rng-cursor) } else { drawing }
}

/// Interpolate a frame (point + unit normal + index fraction) at arc-length
/// distance `s` along the path.
#let _frame-at(fr, cum, s) = {
  let n = fr.len()
  let i = range(n - 1).find(k => cum.at(k + 1) >= s)
  let i = if i == none { calc.max(0, n - 2) } else { i }
  let span = cum.at(i + 1) - cum.at(i)
  let f = if span > 0 { calc.min(1.0, calc.max(0.0, (s - cum.at(i)) / span)) } else { 0.0 }
  let p0 = fr.at(i).at(0)
  let p1 = fr.at(i + 1).at(0)
  let v0 = fr.at(i).at(1)
  let v1 = fr.at(i + 1).at(1)
  let p = (p0.at(0) + (p1.at(0) - p0.at(0)) * f, p0.at(1) + (p1.at(1) - p0.at(1)) * f)
  let v = _unit((v0.at(0) + (v1.at(0) - v0.at(0)) * f, v0.at(1) + (v1.at(1) - v0.at(1)) * f))
  (p, v, s / cum.last(), i)
}

/// Tube geometry as plain data (so verify.typ can assert on it):
///   * `sides-offset`: the outline sits at ± this radius, per t
///   * `inner`: longitudinal lanes on a maximum power-of-two grid; explicit
///     sections preserve each local lane count and residual-width parity
///   * `trans`: transverse cross-section strokes at arc-length positions,
///     with surface-lit width profiles and source-scale spacing
#let _tube-layout(pts, radius, hatch: "l", spacing: 3 * _source-max-shading, coverage: auto,
                  closed: false, per: 12, w: 0.5 * pt, min-w: _source-min-stroke,
                  max-w: _source-max-shading,
                  light: (-0.353553, 0.382683, 0.853553), gamma: 1.0,
                  shift: (0, 0), source-cubic-step: 0,
                  radial-y-sign: -1, shadow-planes: ()) = {
  let src = pts.map(p => _add(p, shift))
  let fr = _frame(_prepare(src, per, closed), closed)
  let n = fr.len()
  let ts = _path-fractions(fr.map(e => e.at(0)), closed)
  let total-length = 0.0
  for i in range(if closed { n } else { n - 1 }) {
    total-length += _dist(fr.at(i).at(0), fr.at(_mod(i + 1, n)).at(0))
  }
  let rfun(t) = calc.max(0.0, _val(radius, t))
  let t-of(i) = ts.at(i)
  let rs = range(n).map(i => rfun(t-of(i)))
  let rmax = calc.max(..rs)
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  // Recover a source cubic from equally spaced samples. This is useful when
  // the input retains four subdivisions per original cubic segment.
  let source-cubic-at(i, f) = {
    let step = int(source-cubic-step)
    if step >= 4 and _mod(step, 4) == 0 and _mod(n - 1, step) == 0 {
      let start = int(calc.floor(i / step)) * step
      let finish = start + step
      if finish < n {
        let p0 = fr.at(start).at(0)
        let p25 = fr.at(start + int(step / 4)).at(0)
        let p75 = fr.at(start + int(3 * step / 4)).at(0)
        let p3 = fr.at(finish).at(0)
        let a = _sub(_sub(_mul(p25, 64), _mul(p0, 27)), p3)
        let b = _sub(_sub(_mul(p75, 64), p0), _mul(p3, 27))
        let p1 = _mul(_sub(_mul(a, 3), b), 1 / 72)
        let p2 = _mul(_add(_mul(a, -1), _mul(b, 3)), 1 / 72)
        let u = calc.clamp((i - start + f) / step, 0.0, 1.0)
        let v = 1 - u
        let point = _add(_add(_mul(p0, v * v * v),
          _mul(p1, 3 * v * v * u)), _add(_mul(p2, 3 * v * u * u),
          _mul(p3, u * u * u)))
        let tangent = _unit(_mul(_add(_add(_mul(_sub(p1, p0), 3 * v * v),
          _mul(_sub(p2, p1), 6 * v * u)), _mul(_sub(p3, p2), 3 * u * u)), 1))
        (point, tangent)
      } else { none }
    } else { none }
  }
  let normal-at(t) = {
    let i = if closed and t >= ts.last() { n - 1 } else {
      let found = range(n - 1).find(k => ts.at(k + 1) >= t)
      if found == none { calc.max(0, n - 2) } else { found }
    }
    let j = if closed { _mod(i + 1, n) } else { calc.min(n - 1, i + 1) }
    let lo = ts.at(i)
    let hi = if closed and i == n - 1 { 1.0 } else { ts.at(j) }
    let f = if hi > lo { calc.clamp((t - lo) / (hi - lo), 0.0, 1.0) } else { 0.0 }
    let cubic = source-cubic-at(i, f)
    if cubic != none {
      let tangent = cubic.at(1)
      (-tangent.at(1), tangent.at(0))
    } else {
      _unit((
        fr.at(i).at(1).at(0) * (1 - f) + fr.at(j).at(1).at(0) * f,
        fr.at(i).at(1).at(1) * (1 - f) + fr.at(j).at(1).at(1) * f,
      ))
    }
  }
  let center-at(t) = {
    let i = if closed and t >= ts.last() { n - 1 } else {
      let found = range(n - 1).find(k => ts.at(k + 1) >= t)
      if found == none { calc.max(0, n - 2) } else { found }
    }
    let j = if closed { _mod(i + 1, n) } else { calc.min(n - 1, i + 1) }
    let lo = ts.at(i)
    let hi = if closed and i == n - 1 { 1.0 } else { ts.at(j) }
    let f = if hi > lo { calc.clamp((t - lo) / (hi - lo), 0.0, 1.0) } else { 0.0 }
    let cubic = source-cubic-at(i, f)
    if cubic != none { cubic.at(0) }
    else { _add(fr.at(i).at(0), _mul(_sub(fr.at(j).at(0), fr.at(i).at(0)), f)) }
  }
  let radius-slope(t) = {
    let eps = 0.0001
    let lo = if closed and t < eps { 1 + t - eps }
             else if closed { t - eps }
             else { calc.max(0.0, t - eps) }
    let hi = if closed and t > 1 - eps { t + eps - 1 }
             else if closed { t + eps }
             else { calc.min(1.0, t + eps) }
    let dt = if closed and (t < eps or t > 1 - eps) { 2 * eps } else { hi - lo }
    if total-length > 0 and dt > 0 {
      ((rfun(hi) - rfun(lo)) / dt) / total-length
    } else { 0.0 }
  }
  let shade(u, t) = {
    let nv = normal-at(t)
    let radial-z = calc.sqrt(calc.max(0.0, 1 - u * u))
    // The upstream layout stores the full diameter in `tubeWidth`, then
    // halves that path before reading its direction for the surface normal.
    // Its axial correction therefore uses the radius slope dr/ds.
    let slope = radius-slope(t)
    let tangent = (nv.at(1), nv.at(0))
    let norm = calc.max(1e-9, calc.sqrt(1 + slope * slope))
    // Convert the 2D frame to world coordinates (y-up), then account for the
    // axial component from a changing radius. Like tubeAnglesToNormalVector,
    // the cross-section normal rotates with the centerline tangent without
    // adding a separate bend-dependent axial correction.
    let nx = (u * nv.at(0) - slope * tangent.at(0)) / norm
    let ny = (radial-y-sign * u * nv.at(1) - slope * tangent.at(1)) / norm
    let nz = radial-z / norm
    let lam = calc.clamp(nx * L.at(0) + ny * L.at(1) + nz * L.at(2), 0.0, 1.0)
    let point = _add(center-at(t), _mul(nv, u * rfun(t)))
    let depth = -calc.abs((1 - radial-z) * 2 * rfun(t))
    let shadowed = shadow-planes.any(shadow => {
      let dz = depth - shadow.depth
      let dx = dz * L.at(0) * L.at(2)
      let dy = dz * L.at(1) * L.at(2)
      let projected = (point.at(0) - dx, point.at(1) - dy)
      if shadow.keys().contains("edge-index") {
        _inside-poly-indexed(projected, shadow.polygon, shadow.edge-index)
      } else { _inside-poly(projected, shadow.polygon) }
    })
    if shadowed { 1.0 } else { calc.pow(1 - lam, gamma) }
  }
  let cov = if coverage == auto {
    if hatch == "t" { 1 / 3 } else if hatch == "s" { 0.4 } else { 0.6 }
  } else { coverage }

  // Use a maximum power-of-two lattice to share lane identities between
  // sections; each piece below retains its source-local lane index and width.
  let divisions = if rmax > 0 and spacing > 0 {
    let divisions = calc.max(1, int(calc.pow(2,
      calc.ceil(calc.log(2 * rmax / spacing, base: 2)))))
    divisions
  } else { 1 }
  let local-divisions(t) = {
    // tubeGenerate subtracts 1/1000 bp from the upper diameter before
    // converting it to a power-of-two hatch count.
    let diameter = 2 * rfun(t) - _source-tube-width-guard
    if diameter > 0 and spacing > 0 {
      calc.max(1, int(calc.pow(2,
        calc.ceil(calc.log(diameter / spacing, base: 2)))))
    } else { 1 }
  }
  // tubeGenerate recursively cuts at every diameter threshold where its
  // power-of-two lane count changes. Keep those cuts explicit so the lane
  // width/parity change is not blended across an ordinary sampling interval.
  let division-cuts = (0.0,)
  let scan-count = calc.max(128, n * 4)
  let previous-divisions = local-divisions(0.0)
  let sampled-divisions = ts.map(local-divisions) + (local-divisions(1.0),)
  let stable-divisions = sampled-divisions.all(d => d == sampled-divisions.first())
  if not stable-divisions {
    for step-index in range(1, scan-count + 1) {
      let lo-scan = (step-index - 1) / scan-count
      let hi-scan = step-index / scan-count
      let next-divisions = local-divisions(hi-scan)
      if next-divisions != previous-divisions {
        let lo = lo-scan
        let hi = hi-scan
        for _ in range(24) {
          let mid = (lo + hi) / 2
          if local-divisions(mid) == previous-divisions { lo = mid }
          else { hi = mid }
        }
        division-cuts.push((lo + hi) / 2)
      }
      previous-divisions = next-divisions
    }
  }
  division-cuts.push(1.0)
  let division-sections = range(division-cuts.len() - 1).map(i => {
    let from = division-cuts.at(i)
    let to = division-cuts.at(i + 1)
    (from: from, to: to, divisions: local-divisions((from + to) / 2))
  })
  let lane-pitch(t) = 2 * rfun(t) / local-divisions(t)
  let inner-n = divisions - 1
  let inner = range(1, divisions).map(k => {
    // `tubeGenerate` interpolates from the q2 boundary toward q3 while lane
    // indices increase. In screen-space coordinates that runs from +r to -r.
    let u = 1.0 - 2.0 * k / divisions
    let active(t) = {
      let d = local-divisions(t)
      let stride = calc.max(1, int(divisions / d))
      _mod(k, stride) == 0
    }
    let width(t) = {
      let r = rfun(t)
      let d = local-divisions(t)
      let stride = calc.max(1, int(divisions / d))
      let local-lane = int(k / stride)
      let ink = if coverage == auto {
        // tubeGenerate gives every second lane the residual left between
        // the local tube diameter and the power-of-two hatch intervals.
        if _mod(local-lane, 2) == 1 {
          max-w * calc.abs(2 * r / d - spacing / 2) / _mp-unit
        } else { max-w }
      } else { cov * 2 * r / d }
      calc.min(max-w, calc.max(0.0, ink)) * shade(u, t)
    }
    let pieces = ()
    if hatch == "l" {
      for (section-index, section) in division-sections.enumerate() {
        let d = section.divisions
        let stride = calc.max(1, int(divisions / d))
        if _mod(k, stride) == 0 {
          let lane = int(k / stride)
          let lane-u = 1.0 - 2.0 * lane / d
          let knot-ts = (section.from,)
          for t in ts {
            if t > section.from + 1e-8 and t < section.to - 1e-8 {
              knot-ts.push(t)
            }
          }
          if closed and division-sections.len() == 1 {
            knot-ts = ts
          } else { knot-ts.push(section.to) }
          let lane-pts = knot-ts.map(t =>
            _add(center-at(t), _mul(normal-at(t), lane-u * rfun(t)))
          )
          let lane-frames = _frame(lane-pts, closed and division-sections.len() == 1)
          let lane-widths = knot-ts.map(t => {
            let r = rfun(t)
            let ink = if coverage == auto {
              if _mod(lane, 2) == 1 {
                max-w * calc.abs(2 * r / d - spacing / 2) / _mp-unit
              } else { max-w }
            } else { cov * 2 * r / d }
            calc.min(max-w, calc.max(0.0, ink)) * shade(lane-u, t)
          })
          pieces.push((frames: lane-frames, widths: lane-widths,
            times: knot-ts, u: lane-u,
            closed: closed and division-sections.len() == 1,
            section-index: section-index,
            seed-offset: k * 7919 + section-index * 104729))
        }
      }
    }
    (
      u: u,
      offset: t => u * rfun(t),
      w: t => if active(t) { width(t) } else { 0.0 },
      pieces: pieces,
    )
  })

  let trans = ()
  if hatch == "t" and n > 1 and not closed {
    let plus = range(n).map(i => _add(fr.at(i).at(0), _mul(fr.at(i).at(1), rfun(ts.at(i)))))
    let minus = range(n).map(i => _sub(fr.at(i).at(0), _mul(fr.at(i).at(1), rfun(ts.at(i)))))
    let arc-table(path) = {
      let out = (0.0,)
      for i in range(path.len() - 1) {
        out.push(out.last() + _dist(path.at(i), path.at(i + 1)))
      }
      out
    }
    let plus-cum = arc-table(plus)
    let minus-cum = arc-table(minus)
    let arc-at(path, cum, t) = {
      let i = range(n - 1).find(k => ts.at(k + 1) >= t)
      let i = if i == none { n - 2 } else { i }
      let span = ts.at(i + 1) - ts.at(i)
      let f = if span > 0 { calc.clamp((t - ts.at(i)) / span, 0.0, 1.0) } else { 0.0 }
      cum.at(i) + f * (cum.at(i + 1) - cum.at(i))
    }
    let time-at(path, cum, s) = {
      let s = calc.clamp(s, 0.0, cum.last())
      let i = range(n - 1).find(k => cum.at(k + 1) >= s)
      let i = if i == none { n - 2 } else { i }
      let length = cum.at(i + 1) - cum.at(i)
      let f = if length > 0 { calc.clamp((s - cum.at(i)) / length, 0.0, 1.0) } else { 0.0 }
      ts.at(i) + f * (ts.at(i + 1) - ts.at(i))
    }
    let point-at(path, t) = {
      let i = range(n - 1).find(k => ts.at(k + 1) >= t)
      let i = if i == none { n - 2 } else { i }
      let span = ts.at(i + 1) - ts.at(i)
      let f = if span > 0 { calc.clamp((t - ts.at(i)) / span, 0.0, 1.0) } else { 0.0 }
      _add(path.at(i), _mul(_sub(path.at(i + 1), path.at(i)), f))
    }
    // Source spacing is expressed on the radius profile as a function of
    // centerline arc length, so slope correction remains independent of the
    // centerline's direction on the page.
    let wt = calc.max(cov * spacing, min-w)
    let target = wt / cov
    let pos = 0.0
    // tubeGenerateAlt increments its global line index before orderFade.
    let line-order = 1
    while pos < 1 - 1e-9 {
      let slope = radius-slope(pos)
      let scorr = 1 / calc.sqrt(1 + slope * slope)
      let step = target / scorr
      let plus-start = arc-at(plus, plus-cum, pos)
      let minus-start = arc-at(minus, minus-cum, pos)
      let plus-target = time-at(plus, plus-cum, plus-start + step)
      let minus-target = time-at(minus, minus-cum, minus-start + step)
      // Compare both offset boundaries at the first candidate time, as the
      // source macro does, then choose the paired boundary for this interval.
      let plus-first = arc-at(plus, plus-cum, plus-target) - plus-start
      let minus-at-plus = arc-at(minus, minus-cum, plus-target) - minus-start
      let forward = plus-first < minus-at-plus
      let chosen = if forward { plus } else { minus }
      let chosen-cum = if forward { plus-cum } else { minus-cum }
      let chosen-start = if forward { plus-start } else { minus-start }
      let other = if forward { minus } else { plus }
      let other-cum = if forward { minus-cum } else { plus-cum }
      let candidate = if forward { plus-target } else { minus-target }
      let other-start = if forward { minus-start } else { plus-start }
      let other-length = arc-at(other, other-cum, candidate) - other-start
      let divisions = calc.max(1, int(calc.round(other-length / step)))
      let correction = (other-length - divisions * step) / divisions
      // The source measures the residual on the opposite boundary, then
      // maps the corrected endpoint back onto the candidate's boundary.
      let finish-distance = arc-at(chosen, chosen-cum, candidate) - correction / 3
      let finish = time-at(chosen, chosen-cum, finish-distance)
      let section-length = calc.max(0.0, arc-at(other, other-cum, finish) - other-start)
      let count = calc.max(1, int(calc.round(section-length / step)))
      let spacing-ratio = section-length / (count * step)
      for section in range(count) {
        let t = time-at(other, other-cum, other-start + section * section-length / count)
        let a = point-at(if forward { plus } else { minus }, t)
        let b = point-at(if forward { minus } else { plus }, t)
        // MetaPost subdivides each cross-section into four pieces before it
        // samples offsetPathTemplate, so its width profile has five knots.
        // Use those same quarter points instead of smoothing between them.
        let cross = range(5).map(k => _add(a, _mul(_sub(b, a), k / 4)))
        let fade-at(f) = {
          let v = 1 / count + (spacing-ratio - 1 / count) * f
          _lat-density(v, line-order)
        }
        let radial-at(f) = if forward { 1 - 2 * f } else { -1 + 2 * f }
        trans.push((t: t, pts: cross,
          profile: f => calc.min(max-w, wt) * fade-at(f) * shade(radial-at(f), t)))
        line-order += 1
      }
      pos = calc.max(pos + 1e-7, calc.min(1.0, finish))
    }
  }

  let silhouette = ()
  if source-cubic-step >= 4 {
    for t in ts {
      silhouette.push(_add(center-at(t), _mul(normal-at(t), rfun(t))))
    }
    for t in ts.rev() {
      silhouette.push(_add(center-at(t), _mul(normal-at(t), -rfun(t))))
    }
  } else {
    for (i, frame) in fr.enumerate() {
      silhouette.push(_add(frame.at(0), _mul(frame.at(1), rs.at(i))))
    }
    for i in range(fr.len()).rev() {
      let frame = fr.at(i)
      silhouette.push(_add(frame.at(0), _mul(frame.at(1), -rs.at(i))))
    }
  }

  (
    frames: fr,
    times: ts,
    rfun: rfun,
    rmax: rmax,
    max-w: max-w,
    center-at: center-at,
    normal-at: normal-at,
    radius-slope: radius-slope,
    shade: shade,
    path-length: total-length,
    cov: cov,
    inner-n: inner-n,
    inner: inner,
    division-sections: division-sections,
    lane-pitch: lane-pitch,
    trans: trans,
    silhouette: silhouette,
    w: w,
  )
}

/// Tube: two offset outlines plus hatching.
/// `seed` controls any thin-brush dashes used by the outlines and hatches.
/// `rng: "metapost"` replays the scaled source stream in longitudinal mode.
///   * `radius` — a number or a function of t (normalized arc length 0..1);
///     varying radius gives cones, waisted tubes, fisiko's fig. 8 ring, …
///   * `hatch: "l"` — longitudinal lines follow the local power-of-two lane
///     count, with paths cut where the diameter crosses a spacing threshold
///   * `hatch: "t"` — transverse cross-section strokes whose width follows
///     surface lighting; very thin regions become ink-conserving dashes
///   * `hatch: "s"` — seeded, slightly varied round dots on source-scale
///     longitudinal lanes; local ink width controls dot density and
///     `dot-density` adjusts the source-segment compensation
///   * `hatch: none` — outline only
///   * `source-cubic-step` — reconstruct centerline cubics from input samples
///     when each source cubic has this many equal parameter intervals; use 0
///     to retain the default polyline frame
#let tube(pts, radius, hatch: "l", spacing: 3 * _source-max-shading, coverage: auto, closed: false,
          w: _source-min-stroke, per: 12, min-w: _source-min-stroke, period: _source-dash-length,
          max-w: _source-max-shading, light: (-0.353553, 0.382683, 0.853553),
          gamma: 1.0, seed: 0, rng: "keyed", shift: (0, 0),
          dot-size: _source-max-shading, dot-step: _source-max-shading,
          dot-range: (0.9, 1.2), dot-density: 0.56, end-caps: true,
          source-cubic-step: 0,
          _radial-y-sign: -1, _shadow-planes: (),
          _random-stream: none, _rng-offset: 0, _with-rng: false) = {
  assert(rng == "keyed" or rng == "metapost",
    message: "rng must be \"keyed\" or \"metapost\"")
  assert(source-cubic-step == 0 or (source-cubic-step >= 4
    and source-cubic-step == int(source-cubic-step)
    and _mod(int(source-cubic-step), 4) == 0),
    message: "source-cubic-step must be 0 or a positive multiple of 4")
  assert(rng != "metapost" or hatch == "l",
    message: "rng: \"metapost\" is currently supported for longitudinal tube hatches")
  let hatch-spacing = if hatch == "s" { calc.min(spacing, dot-size * _source-stipple-spacing-ratio) } else { spacing }
  let L = _tube-layout(pts, radius, hatch: hatch, spacing: hatch-spacing,
                       coverage: coverage, closed: closed, per: per,
                       w: w, min-w: min-w, max-w: max-w, light: light,
                       gamma: gamma, shift: shift,
                       source-cubic-step: source-cubic-step,
                       radial-y-sign: _radial-y-sign,
                       shadow-planes: _shadow-planes)
  let random-stream = if _random-stream != none { _random-stream } else if rng == "metapost" {
    _metapost-rng-sequence(seed,
      calc.max(1024, L.frames.len() * calc.max(1, L.inner.len()) * 16))
  } else { none }
  let rng-cursor = _rng-offset
  let center-cum = (0.0,)
  for i in range(L.frames.len() - 1) {
    center-cum.push(center-cum.last() + _dist(L.frames.at(i).at(0), L.frames.at(i + 1).at(0)))
  }
  let src = pts.map(p => _add(p, shift))
  let outlines = (
    stroke-ink(src, w, offset: L.rfun, closed: closed, per: per,
               min-w: min-w, period: period, seed: seed),
    stroke-ink(src, w, offset: t => -(L.rfun)(t), closed: closed, per: per,
               min-w: min-w, period: period, seed: seed),
  )
  let els = ()
  let end-cap-elements = ()
  let tube-edge-points(section, side) = {
    let knots = (section.from,)
    for t in L.times {
      if t > section.from + 1e-8 and t < section.to - 1e-8 {
        knots.push(t)
      }
    }
    knots.push(section.to)
    knots.map(t => _add((L.center-at)(t),
      _mul((L.normal-at)(t), side * (L.rfun)(t))))
  }
  let tube-edge-width(section, side) = t => {
    let d = section.divisions
    let endpoint-lane = if side > 0 { 0 } else { d }
    let residual = if _mod(endpoint-lane, 2) == 1 {
      calc.abs(2 * (L.rfun)(t) / d - spacing / 2) / _mp-unit
    } else { 1.0 }
    calc.min(max-w, calc.max(0.0,
      max-w * (L.shade)(side, t) * residual))
  }
  // MetaPost closes open tube outlines across both ends. Connect the two
  // offset boundaries here as well; closed centerlines have no end caps.
  if not closed and end-caps {
    for (i, t) in ((0, 0.0), (L.frames.len() - 1, 1.0)) {
      let frame = L.frames.at(i)
      let rad = (L.rfun)(t)
      if rad > 0.000001 {
        let a = _add(frame.at(0), _mul(frame.at(1), rad))
        let b = _add(frame.at(0), _mul(frame.at(1), -rad))
        end-cap-elements.push(stroke-path((a, b),
          stroke: w * 1mm + black, closed: false, per: 0))
      }
    }
  }
  if hatch == "l" {
    if rng == "metapost" {
      // The source recurses into a narrower longitudinal section before it
      // advances that section's lane index. Preserve that section-major draw
      // order while carrying the global random cursor between brush paths.
      for section-index in range(L.division-sections.len()) {
        let section = L.division-sections.at(section-index)
        let edge = stroke-ink(tube-edge-points(section, 1),
          tube-edge-width(section, 1), closed: false, per: 0,
          min-w: min-w, period: period, seed: seed,
          _random-stream: random-stream, _rng-offset: rng-cursor,
          _with-rng: true, _source-rounding: true)
        els.push(edge.at(0))
        rng-cursor += edge.at(1)
        for it in L.inner {
          for piece in it.pieces {
            if piece.section-index != section-index { continue }
            let result = _ink-loops(piece.frames, piece.widths, piece.closed,
              min-w, period, random-stream: random-stream,
              rng-offset: rng-cursor, with-rng: true,
              dash-extra: _source-brush-width-guard, dash-cap: 1,
              source-rounding: true)
            els.push(place(top + left, _fill(result.at(0), black)))
            rng-cursor += result.at(1)
          }
        }
        let edge = stroke-ink(tube-edge-points(section, -1),
          tube-edge-width(section, -1), closed: false, per: 0,
          min-w: min-w, period: period, seed: seed,
          _random-stream: random-stream, _rng-offset: rng-cursor,
          _with-rng: true, _source-rounding: true)
        els.push(edge.at(0))
        rng-cursor += edge.at(1)
      }
    } else {
      for (section-index, section) in L.division-sections.enumerate() {
        els.push(stroke-ink(tube-edge-points(section, 1),
          tube-edge-width(section, 1), closed: false, per: 0,
          min-w: min-w, period: period,
          seed: seed + 500000 + section-index * 2))
        for it in L.inner {
          for piece in it.pieces {
            if piece.section-index != section-index { continue }
            let loops = _ink-loops(piece.frames, piece.widths, piece.closed,
              min-w, period, seed: seed + piece.seed-offset,
              dash-extra: _source-brush-width-guard,
              dash-cap: 1)
            els.push(place(top + left, _fill(loops, black)))
          }
        }
        els.push(stroke-ink(tube-edge-points(section, -1),
          tube-edge-width(section, -1), closed: false, per: 0,
          min-w: min-w, period: period,
          seed: seed + 500001 + section-index * 2))
      }
    }
  } else if hatch == "s" {
    for (i, it) in L.inner.enumerate() {
      // thinBrushGenerate.stipples draws three tracks around each tube lane,
      // splitting its ink width evenly and offsetting tracks by one third of
      // twice the local lane pitch. Dots stay on their tracks (no normal jitter).
      for lane in range(3) {
        let side = lane - 1
        let track-offset(t) = (it.offset)(t) + side * 2 * (L.lane-pitch)(t) / 3
        let key = i * 7919 + lane * 104729
        let size-scale = dot-range.at(0) + (dot-range.at(1) - dot-range.at(0)) * _rng(seed, key, 11)
        let lane-dot-size = dot-size * size-scale
        let clip-lane-dot(dot, t) = {
          if closed { return dot }
          let (p, n, _, _) = _frame-at(L.frames, center-cum, t * L.path-length)
          let lane-offset = track-offset(t)
          let side = if lane-offset < 0 { -1.0 } else { 1.0 }
          let side-origin = _add(p, _mul(n, side * (L.rfun)(t)))
          let planes = ((side-origin, _mul(n, side)),)

          // The source clips the entire stipple image to the tube silhouette.
          // The local side plane trims dots at the curved sides. End-cap
          // planes only apply within one dot radius of their endpoint; using
          // their infinite half-planes along a bent tube incorrectly removes
          // dots wherever the centerline later crosses those planes.
          let start = L.frames.first()
          let start-tangent = (start.at(1).at(1), -start.at(1).at(0))
          let start-origin = _add(start.at(0), _mul(start.at(1), track-offset(0)))
          let end = L.frames.last()
          let end-tangent = (end.at(1).at(1), -end.at(1).at(0))
          let end-origin = _add(end.at(0), _mul(end.at(1), track-offset(1)))
          if t * L.path-length <= dot.at("diameter") / 2 {
            planes.push((start-origin, _mul(start-tangent, -1)))
          }
          if (1 - t) * L.path-length <= dot.at("diameter") / 2 {
            planes.push((end-origin, end-tangent))
          }
          _clip-dot-to-planes(dot, planes)
        }
        let in-closed-tube(t) = {
          not closed or calc.abs(track-offset(t)) + lane-dot-size / 2 <= (L.rfun)(t)
        }
        els.push(stroke-stipple(src,
        t => if in-closed-tube(t) and (it.w)(t) / 3 >= dot-size * _source-min-stipple-width-ratio { (it.w)(t) / 3 } else { 0.0 },
          offset: track-offset,
          closed: closed, per: per,
          dot-size: lane-dot-size, step: dot-step * size-scale, seed: seed + key,
          normal-jitter: 0, ink-space: true, independent-spacing: false,
          density: dot-density,
          _clip-dot: if closed { none } else { clip-lane-dot }))
      }
    }
  }
  if L.trans.len() > 0 {
    els += L.trans.map(tr => stroke-ink(tr.pts, tr.profile, closed: false, per: 0,
      min-w: min-w, period: period, seed: seed))
  }
  // MetaPost draws the tube hatches first, then its two thin boundary paths.
  let drawing = _join((..els, ..outlines, ..end-cap-elements))
  if _with-rng { (drawing, rng-cursor) } else { drawing }
}

// Intersect evenly spaced scanlines with a closed polygon. Each line returns
// one or more inside intervals, including concave polygons and disjoint cuts.
#let _source-scanline-segments(poly, angle, spacing) = {
  // MetaPost rotates the polygon and intersects horizontal fixed-point rays.
  // Convert Typst millimetres with plain.mp's quantized mm scalar, then keep
  // the projection, row grid, edge intersections and inverse rotation in
  // signed 16.16 arithmetic.
  let one = 65536
  let source-bp-per-mm = 185771
  let sine = int(calc.round(_sin(angle) * one))
  let cosine = int(calc.round(_cos(angle) * one))
  let mul(a, b) = _mp-fixed-round-ratio(a * b, one)
  let rotate(point, direction) = (
    mul(point.at(0), cosine) - mul(point.at(1), sine * direction),
    mul(point.at(0), sine * direction) + mul(point.at(1), cosine),
  )
  let source-poly = poly.map(point => (
    int(calc.round(point.at(0) * source-bp-per-mm)),
    int(calc.round(point.at(1) * source-bp-per-mm)),
  ))
  let rotated = source-poly.map(point => rotate(point, -1))
  let ymin = calc.min(..rotated.map(point => point.at(1)))
  let ymax = calc.max(..rotated.map(point => point.at(1)))
  let spacing-fixed = int(calc.round(spacing * source-bp-per-mm))
  if spacing-fixed <= 0 or ymax <= ymin { return () }
  let count = calc.max(1, int(calc.round((ymax - ymin) / spacing-fixed)))
  let row-step = _mp-fixed-round-ratio(ymax - ymin, count)
  // Source llcorner/lrcorner equal the transformed vertex extrema on the
  // traced S104 row. The Typst ray frame is one 16.16 unit left of those
  // source bounds across all 142 rows; keep this measured correction named
  // separately until the frame conversion itself is derived.
  let source-ray-grid-correction = 1
  let xmin = calc.min(..rotated.map(point => point.at(0))) + source-ray-grid-correction
  let xmax = calc.max(..rotated.map(point => point.at(0))) + source-ray-grid-correction
  let edge-curves = range(poly.len()).map(i => _mp-fixed-line-cubic(
    rotated.at(i), rotated.at(_mod(i + 1, poly.len()))))
  let page-point(local) = {
    let point = rotate(local, 1)
    (point.at(0) / one * _mp-unit, point.at(1) / one * _mp-unit)
  }
  let segments = ()
  for row in range(count + 1) {
    // The source advances rows from the low side of its y-up rotated box.
    // In the page's y-down frame that is the high side, so anchor the same
    // fixed step grid there instead of deriving the first line from ymin.
    let height = ymax - (count - row) * row-step
    let ray = _mp-fixed-line-cubic((xmin, height), (xmax, height))
    let reverse-ray = ray.rev()
    let forward-hit = intersection-times(ray, edge-curves)
    let reverse-hit = intersection-times(reverse-ray, edge-curves)
    if forward-hit.at(0) >= 0 and reverse-hit.at(0) >= 0 {
      let clipped-start = _mp-fixed-cubic-at(ray, forward-hit.at(0))
      let clipped-end = _mp-fixed-cubic-at(reverse-ray, reverse-hit.at(0))
      let u0 = clipped-start.at(0)
      let u1 = clipped-end.at(0)
      if u1 - u0 > int(calc.round(0.001 / _mp-unit * one)) {
        // MetaPost clips the rotated `--` hatch line, then rotates that new
        // cubic back into page coordinates before pathSubdivide. Retain the
        // rotated fixed controls so subdivision sees the same `--` rounding
        // instead of treating the final endpoints as an ideal straight line.
        let clipped-cubic = _mp-fixed-line-cubic(
          (u0, height), (u1, height)).map(point => rotate(point, 1))
        segments.push((page-point((u0, height)), page-point((u1, height)), row, count,
          (forward-hit, reverse-hit), (xmax - xmin) / one * _mp-unit,
          clipped-cubic, (u0, height), (u1, height), ray, rotated, source-poly))
      }
    }
  }
  segments
}

#let _scanline-segments(poly, angle, spacing, fit: false, source-fixed: false) = {
  if poly.len() < 3 or spacing <= 0 { return () }
  if source-fixed { return _source-scanline-segments(poly, angle, spacing) }
  let d = (_cos(angle), _sin(angle))
  let n = (-d.at(1), d.at(0))
  let projections = poly.map(p => _dot(p, n))
  let lo = calc.min(..projections)
  let hi = calc.max(..projections)
  // flatSurface fits its step to the rotated bounds using round(height / d);
  // other polygon hatching APIs keep a fixed user-specified spacing.
  let count = calc.max(1, int(if fit {
    calc.round((hi - lo) / spacing)
  } else { calc.ceil((hi - lo) / spacing) }))
  let row-step = if fit { (hi - lo) / count } else { spacing }
  let segments = ()
  for row in range(count + 1) {
    let offset = lo + row * row-step
    let hits = ()
    for i in range(poly.len()) {
      let a = poly.at(i)
      let b = poly.at(calc.rem(i + 1, poly.len()))
      let va = _dot(a, n) - offset
      let vb = _dot(b, n) - offset
      if (va <= 0 and vb > 0) or (vb <= 0 and va > 0) {
        let t = va / (va - vb)
        hits.push(_dot(_add(a, _mul(_sub(b, a), t)), d))
      }
    }
    let sorted = hits.sorted()
    for j in range(0, sorted.len() - 1, step: 2) {
      let u0 = sorted.at(j)
      let u1 = sorted.at(j + 1)
      if u1 - u0 > 0.001 {
        segments.push((
          _add(_mul(d, u0), _mul(n, offset)),
          _add(_mul(d, u1), _mul(n, offset)),
          row,
          count,
        ))
      }
    }
  }
  segments
}

// MetaPost rounds each scalar operation in flatSurface's width callback to
// 16.16 before offsetPathTemplate stores the resulting q-width knot.
#let _flat-surface-source-width(t, line-length, total-width, row-fraction,
                                shade, scale) = {
  let q = _mp-scalar-rounded
  let ratio = q(line-length / total-width)
  let row-position = q(row-fraction)
  let s1 = q(_sin(q(q(t) * 180)))
  let s2 = q(_sin(q(row-position * 180)))
  let envelope = q(q(s1 * ratio) * s2)
  let root = q(calc.sqrt(calc.max(0.0, envelope)))
  // Match MetaPost's source expression `6/7sqrt(root)`: it multiplies by
  // six before dividing by seven, which differs by one fixed unit from
  // rounding `6/7` first and then multiplying by the root.
  let fade = q(q(6 * root) / 7)
  let remain = q(1 - fade)
  let light-factor = q(q(1 / 15) + q(shade))
  let base-bp = q(scale * q(_source-min-stroke / _mp-unit))
  let width-bp = q(q(base-bp * light-factor) * remain)
  _mp-rounded(width-bp * _mp-unit)
}

/// Parallel clipped strokes inside a polygon. `style: "glass"` leaves
/// periodic gaps to suggest a transparent material.
#let _dash-segment(a, b, on, off, phase: 0) = {
  let direction = _sub(b, a)
  let length = _len(direction)
  if on <= 0 or length <= phase { return () }
  let pieces = ()
  let count = int(calc.ceil((length - phase) / (on + off))) + 1
  for i in range(count) {
    let start = phase + i * (on + off)
    let finish = calc.min(length, start + on)
    if finish > start {
      pieces.push((_add(a, _mul(direction, start / length)),
                   _add(a, _mul(direction, finish / length))))
    }
  }
  pieces
}

#let solid(poly, angle: 45, style: "opaque", spacing: none,
           stroke: _source-min-stroke * 1mm + black) = {
  let line-spacing = if spacing == none { 4.5 * _source-max-shading } else { spacing }
  let segs = _scanline-segments(poly, angle, line-spacing)
  let items = ()
  for s in segs {
    let row = s.at(2)
    if style == "glass" {
      let density = _source-max-shading * 3
      let family = calc.rem(row, 4)
      if family == 2 { continue }
      let variation = 0.0
      let (on, off, phase) = if family == 0 {
        ((8 - variation) * density, (4 + variation) * density, 0.0)
      } else {
        (6 * density, 5 * density, density)
      }
      for dash in _dash-segment(s.at(0), s.at(1), on, off, phase: phase) {
        items.push(stroke-path(dash, stroke: stroke, closed: false, per: 0))
      }
    } else {
      items.push(stroke-path((s.at(0), s.at(1)), stroke: stroke, closed: false, per: 0))
    }
  }
  _join(items)
}

/// A clipped set of strokes whose width increases across the polygon.
#let gradient-shade(poly, angle: 90, spacing: none,
                    min-w: _source-min-stroke / 4,
                    max-w: _source-min-stroke, seed: 0) = {
  let line-spacing = if spacing == none { 3 * _source-max-shading } else { spacing }
  let segs = _scanline-segments(poly, angle, line-spacing)
  let items = ()
  for s in segs {
    let t = s.at(2) / calc.max(1, s.at(3))
    let w = min-w + (max-w - min-w) * t
    items.push(stroke-ink((s.at(0), s.at(1)), w, closed: false, per: 0,
                          seed: seed + s.at(2)))
  }
  _join(items)
}

/// A shaded plane, with either parallel hatches or deterministic stipples.
#let flat-surface(poly, normal, angle: 30, style: "hatch", spacing: none,
                  dot-size: 1.5 * _source-min-stroke, dot-step: 0.75 * _source-min-stroke, seed: 0,
                  light: (-0.353553, 0.382683, 0.853553),
                  rng: "keyed", rng-offset: 0, with-rng: false) = {
  let nn = calc.sqrt(normal.at(0) * normal.at(0) + normal.at(1) * normal.at(1) + normal.at(2) * normal.at(2))
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let lam = calc.max(0.0, (normal.at(0) * light.at(0) + normal.at(1) * light.at(1) + normal.at(2) * light.at(2)) / (nn * ln))
  let shade = calc.pow(1 - lam, 1.0)
  let line-spacing = if spacing == none {
    if style == "stipples" { dot-size * _source-stipple-spacing-ratio } else { 3 * _source-max-shading }
  } else { spacing }
  let source-fixed-scanlines = rng == "metapost" and style == "hatch"
  let segs = _scanline-segments(poly, angle, line-spacing, fit: true,
    source-fixed: source-fixed-scanlines)
  assert(rng == "keyed" or rng == "metapost",
    message: "rng must be \"keyed\" or \"metapost\"")
  assert(rng == "keyed" or style != "stipples",
    message: "MetaPost stream mode is currently supported for hatch style only")
  let stream = if rng == "metapost" {
    _metapost-rng-sequence(seed, rng-offset + calc.max(128, segs.len() * 128))
  } else { none }
  let cursor = rng-offset
  // MetaPost scans its y-up bounding box from low to high. After a page's
  // vertical axis is flipped, that is the reverse of Typst's scanline order.
  let draw-segs = if rng == "metapost" and style == "hatch" { segs.rev() } else { segs }
  let along = (_cos(angle), _sin(angle))
  let along-projections = poly.map(p => _dot(p, along))
  let total-width = if source-fixed-scanlines and segs.len() > 0 {
    segs.first().at(5)
  } else { calc.max(..along-projections) - calc.min(..along-projections) }
  let items = ()
  for s in draw-segs {
    // flatSurface calls pathSubdivide(aHatch, 3 + round(uniformdeviate(2))).
    // Its random count changes the path-time knots seen by brushGenerate even
    // though the hatch itself is geometrically straight.
    let requested-subdivisions = if rng == "metapost" {
      3 + int(calc.floor(stream.at(cursor) * 2 + 0.5))
    } else { 24 }
    if rng == "metapost" and style != "stipples" { cursor += 1 }
    // pathSubdivide recursively accumulates 16.16 path-time steps. For 3 and
    // 5 requested pieces, rounding leaves the final accumulated time just
    // below 1, so the source emits one additional, very short final segment.
    let subdivision-times = if rng == "metapost" {
      _mp-path-subdivision-times(requested-subdivisions)
    } else { range(requested-subdivisions + 1).map(i => i / requested-subdivisions) }
    let row-fraction = s.at(2) / calc.max(1, s.at(3))
    let source-fixed = source-fixed-scanlines
    let pts = subdivision-times.map(t => if source-fixed {
      _mp-fixed-cubic-at(s.at(6), t).map(value => value / 65536 * _mp-unit)
    } else { _add(s.at(0), _mul(_sub(s.at(1), s.at(0)), t)) })
    let source-arc-positions = if source-fixed {
      let positions = (0.0,)
      for i in range(pts.len() - 1) {
        positions.push(positions.last() + _mp-fixed-pyth-distance(
          pts.at(i), pts.at(i + 1)))
      }
      positions
    } else { none }
    let line-length = if source-fixed { source-arc-positions.last() }
      else { _dist(s.at(0), s.at(1)) }
    let width(t, end-fade, scale) = {
      let envelope = (
        calc.sin(180deg * t)
        * (line-length / calc.max(total-width, 0.000001))
        * calc.sin(180deg * row-fraction)
      )
      scale * _source-min-stroke * (1 / 15 + shade) * (1 - end-fade * calc.sqrt(calc.max(0.0, envelope)))
    }
    let source-fixed-width(t) = _flat-surface-source-width(
      t, line-length, total-width, row-fraction, shade, 2)
    if style == "stipples" {
      items.push(stroke-stipple-brush(pts,
        t => width(t, 5 / 6, dot-size / _source-min-stroke),
        closed: false, per: 0, dot-size: dot-size,
        track-spacing: dot-size * _source-stipple-spacing-ratio, dot-range: (0.9, 1.2),
        density: 0.72 * (0.75 * _source-min-stroke / dot-step),
        seed: seed + s.at(2)))
    } else {
      if rng == "metapost" {
        let active-width(t) = if source-fixed {
          source-fixed-width(t)
        } else { width(t, 6 / 7, 2) }
        let frames = _frame(pts, false)
        let fractions = _path-fractions(frames.map(e => e.at(0)), false)
        let callback-widths = fractions.map(active-width)
        let source-width-fixed = if source-fixed {
          callback-widths.map(value =>
            int(calc.round(value / _mp-unit * 65536)))
        } else { none }
        let drawn = stroke-ink(pts, active-width,
          closed: false, per: 0, min-w: _source-min-stroke,
          period: _source-dash-length, seed: seed + s.at(2),
          _random-stream: stream, _rng-offset: cursor, _with-rng: true,
          _source-rounding: true,
          _source-width-fixed: source-width-fixed,
          _source-arc-positions: source-arc-positions)
        items.push(drawn.at(0))
        cursor += drawn.at(1)
      } else {
        items.push(stroke-ink(pts, t => width(t, 6 / 7, 2),
          closed: false, per: 0, min-w: _source-min-stroke,
          period: _source-dash-length, seed: seed + s.at(2)))
      }
    }
  }
  let drawing = _join(items)
  if with-rng { (drawing, cursor) } else { drawing }
}

#let _band-quads(outer, inner, closed: true) = {
  if outer.len() != inner.len() or outer.len() < 3 { return () }
  let count = if closed { outer.len() } else { outer.len() - 1 }
  range(count).map(i => {
    let j = _mod(i + 1, outer.len())
    (outer.at(i), outer.at(j), inner.at(j), inner.at(i))
  })
}

/// Raised edge along an open centerline: shade the offset band and outline it.
#let solid-surface(path, thickness: 2.5, angle: 45, spacing: 0.65) = {
  let outer = resample(path, per: 12, closed: false)
  let inset = offset-path(path, thickness, closed: false)
  let quads = _band-quads(outer, inset, closed: false)
  let outline = outer + inset.rev()
  _join((
    ..quads.map(q => solid(q, angle: angle, spacing: spacing)),
    stroke-path(outline, stroke: 0.35pt + black, closed: true, per: 0),
  ))
}

// ---------------------------------------------------------------------------
// geometry helpers & composition
// ---------------------------------------------------------------------------

/// Sampled circle, centred at `center`.
#let circle-pts(r, n, center: (0, 0)) = {
  range(n).map(j => {
    let a = 360 * j / n
    _add(center, (r * _cos(a), r * _sin(a)))
  })
}

/// Sampled circular arc from a0 to a1 degrees (screen angles, y down).
#let arc-pts(r, a0, a1, n: 40, center: (0, 0)) = {
  range(n + 1).map(j => {
    let a = a0 + (a1 - a0) * j / n
    _add(center, (r * _cos(a), r * _sin(a)))
  })
}

/// Label anchored at a point (default: centred on it).
/// Note: `place`'s alignment positions content *within the parent*, so we
/// place a zero-sized box at the anchor point and align the label inside it.
#let tag(body, pos, anchor: center + horizon) = {
  place(top + left,
    dx: pos.at(0) * 1mm,
    dy: pos.at(1) * 1mm,
    box(width: 0pt, height: 0pt, align(anchor, body)),
  )
}

/// Join a list of drawing elements into one content value.
#let combine(items) = _join(items)

/// A fixed-size drawing area in millimetres; compose children with `+`.
#let canvas(w, h, stroke: none, ..children) = {
  box(
    width: w * 1mm,
    height: h * 1mm,
    stroke: stroke,
    inset: 0pt,
    _join(children.pos()),
  )
}

// ---------------------------------------------------------------------------
// L'Hôpital's pulley (fisiko's fig. 18)
// ---------------------------------------------------------------------------

/// Geometry of L'Hôpital's pulley, in units where the ceiling span is AB.
/// y points down; A and B sit on the ceiling line.
///   rope 1: A → D, length l   (the pulley's axle hangs at D)
///   rope 2: B → D → C, length m   (the weight C drops straight below D)
/// Equilibrium of the weightless pulley gives, with y1 = √(l² − x1²),
///   2·AB·x1² − l²·x1 − l²·AB = 0
///   ⟹ x1 = (l² + l·√(l² + 8·AB²)) / (4·AB)
/// which is exactly fisiko's `(l**2 + abs(l)*((sqrt(8)*AB)++l))/4AB`.
/// Returns points as data so verify.typ can assert on them.
#let _pulley-geometry(AB, l, m, d1: 2 / 3) = {
  let x1 = (l * l + l * calc.sqrt(l * l + 8 * AB * AB)) / (4 * AB)
  let y1 = pyth-sub(l, x1)
  let A = (0.0, 0.0)
  let B = (AB * 1.0, 0.0)
  let D = (x1, y1)
  let BD = pyth-add(AB - x1, y1)
  let y2 = m - BD
  let C = (x1, y1 + y2)
  let r3 = 5 * d1 / 12                     // groove radius (5/6·d1 across)
  // Wheel centre: the line through D parallel to DC and the line through D
  // parallel to DB, each pushed r3 into the angle at D — MetaPost's `whatever`
  // construction, restated as two linear equations.
  let uC = (0.0, 1.0)
  let uB = ((B.at(0) - D.at(0)) / BD, (B.at(1) - D.at(1)) / BD)
  let bis = _unit(_add(uB, uC))
  let nC = (-uC.at(1), uC.at(0))
  let nB = (-uB.at(1), uB.at(0))
  let sgn(v) = if v >= 0 { 1.0 } else { -1.0 }
  let c1 = _add(D, _mul(nC, r3 * sgn(_dot(nC, bis))))
  let c2 = _add(D, _mul(nB, r3 * sgn(_dot(nB, bis))))
  let E = line-intersect(c1, uC, c2, uB)
  (A: A, B: B, C: C, D: D, E: E, r3: r3, BD: BD, x1: x1, y1: y1, y2: y2, d1: d1)
}

/// The area centroid of a simple closed polygon. Coordinates use millimetres;
/// the input may omit the repeated closing point.
#let polygon-centroid(poly) = {
  let twice-area = 0.0
  let cx = 0.0
  let cy = 0.0
  for i in range(poly.len()) {
    let a = poly.at(i)
    let b = poly.at(_mod(i + 1, poly.len()))
    let cross = a.at(0) * b.at(1) - a.at(1) * b.at(0)
    twice-area += cross
    cx += (a.at(0) + b.at(0)) * cross
    cy += (a.at(1) + b.at(1)) * cross
  }
  if calc.abs(twice-area) < 1e-9 { poly.at(0) }
  else { (cx / (3 * twice-area), cy / (3 * twice-area)) }
}

/// Mark the area centroid with a small ring and crosshair.
#let centroid-marker(poly, size: 1.4, stroke: 0.45pt + black) = {
  let c = polygon-centroid(poly)
  _join((
    stroke-path(circle-pts(size / 2, 24, center: c), stroke: stroke, closed: true, per: 0),
    stroke-path((_add(c, (-size, 0)), _add(c, (size, 0))), stroke: stroke, closed: false, per: 0),
    stroke-path((_add(c, (0, -size)), _add(c, (0, size))), stroke: stroke, closed: false, per: 0),
  ))
}

/// Shaded pulley wheel with rim, groove and axle details.
#let pulley-wheel(d, center: (0, 0), rings: auto, seed: 0) = {
  let first = 3 / 5 * d
  let middle = 7 / 9 * d
  let last = 8 / 9 * d
  let step = 2 * _source-spacing
  let n = if rings == auto { int(calc.floor((last - first) / step)) + 1 } else { rings }
  let items = ()
  for i in range(n) {
    let diameter = if rings == auto { first + i * step }
      else { first + (last - first) * i / calc.max(1, n - 1) }
    if diameter > last { continue }
    let outer = diameter <= middle
    let lat = if outer { calc.asin(diameter / (4 * d)) } else { 30deg }
    let angle-offset = if outer { 0 } else { 180 }
    let pts = circle-pts(diameter / 2, 96, center: center)
    items.push(stroke-ink(pts, t => {
      let theta = 360 * t + angle-offset
      let nx = calc.sin(lat) * _cos(theta)
      let ny = calc.sin(lat) * _sin(theta)
      let nz = calc.cos(lat)
      let lightness = calc.max(0.0, 1 - (-0.353553 * nx + 0.382683 * ny + 0.853553 * nz))
      let base = if outer { 2 / 3 } else { 1 / 4 }
      _source-min-stroke * (base + lightness)
    }, closed: true, per: 0, min-w: _source-min-stroke,
       period: _source-dash-length, seed: seed + i))
  }
  for diameter in (middle, last, d, first) {
    items.push(stroke-path(circle-pts(diameter / 2, 120, center: center),
      stroke: _source-min-stroke * 1mm + black, closed: true, per: 0))
  }
  items.push(stroke-path(circle-pts(d / 16, 48, center: center),
    stroke: 3 * _source-min-stroke * 1mm + black, closed: true, per: 0))
  _join(items)
}

/// Source-style pulley with a partial wheel, support silhouette, and axle.
/// `angle` rotates the support in screen-space degrees.
#let pulley(d, center: (0, 0), groove: 5 / 6, angle: 0) = {
  let c = _cos(angle)
  let s = _sin(angle)
  let tx(p) = _add(center, (p.at(0) * c - p.at(1) * s,
                             p.at(0) * s + p.at(1) * c))
  let rim-r = d / 2
  let support-y = 2 / 3 * d
  let support-r = 3 / 10 * d
  // pulleyOutline uses the support arc endpoints' verticals to intersect the
  // outer rim. Its visible rim arc therefore runs from 90°+δ to 450°−δ,
  // where δ is set by the inner support radius, not the outer wheel radius.
  let support-x = support-r * _cos(45)
  let rim-offset = calc.asin(support-x / rim-r)
  let rim-offset-deg = rim-offset / 1deg
  let silhouette-rim = arc-pts(rim-r, 90 + rim-offset-deg,
    450 - rim-offset-deg, n: 96)
  let silhouette = (silhouette-rim.map(tx) + (tx((support-x, support-y)),
                                    tx((-support-x, support-y))))
  let support = (arc-pts(support-r, 135, 405, n: 72).map(tx)
    + (tx((support-r * _cos(45), support-y)),
       tx((-support-r * _cos(45), support-y))))
  let elements = (
    place(top + left, _fill((silhouette,), white)),
    pulley-wheel(d, center: center),
    // The source clips its shaded wheel to this support face.
    place(top + left, _fill((support,), white)),
    // pulleyWheel already draws the full thinpen rim; pulleyOutline is only
    // used to occlude the ropes, while the support itself uses thinpen too.
    stroke-path(support, stroke: _source-min-stroke * 1mm + black,
      closed: true, per: 0),
    stroke-path(circle-pts(d / 12, 64, center: center),
      stroke: 0.45pt + black, closed: true, per: 0),
  )
  if groove != 5 / 6 {
    elements.push(stroke-path(circle-pts(d / 2 * groove, 96, center: center),
      stroke: 0.45pt + black, closed: true, per: 0))
  }
  _join(elements)
}

/// A wheel with a rim, hub, and evenly spaced spokes.
#let wheel(d, center: (0, 0), spokes: 6, rim: 0.82,
           stroke: 0.55pt + black, style: "spoked", seed: 0) = {
  assert(style == "spoked" or style == "source",
    message: "wheel style must be spoked or source")
  let R = d / 2
  if style == "source" {
    let inner-d = 2 / 8 * d
    let outer-hatch-d = 7 / 8 * d - 2 * _source-spacing
    let n = calc.max(1, int(calc.ceil((outer-hatch-d - inner-d) / (2 * _source-spacing))) + 1)
    let rings = ()
    for i in range(n) {
      let diameter = inner-d + i * 2 * _source-spacing
      if diameter > outer-hatch-d { continue }
      let lat = calc.asin(diameter / (4 * d))
      let pts = circle-pts(diameter / 2, 96, center: center)
      rings.push(stroke-ink(pts, t => {
        let theta = 360 * t + 180
        let nx = calc.sin(lat) * _cos(theta)
        let ny = calc.sin(lat) * _sin(theta)
        let nz = calc.cos(lat)
        let lightness = calc.max(0.0, 1 - (-0.353553 * nx + 0.382683 * ny + 0.853553 * nz))
        _source-min-stroke * (2 / 3 + lightness)
      }, closed: true, per: 0, min-w: _source-min-stroke,
         period: _source-dash-length, seed: seed + i))
    }
    let rim-d = d - 6 * _source-min-stroke
    _join((
      place(top + left, _fill((circle-pts(d / 2, 120, center: center),), black)),
      place(top + left, _fill((circle-pts(rim-d / 2, 120, center: center),), white)),
      ..rings,
      sphere(inner-d, center: center, seed: seed),
      stroke-path(circle-pts(R, 120, center: center), stroke: _source-min-stroke * 1mm + black, closed: true, per: 0),
    ))
  } else {
  let inner-r = R * rim
  let items = (
    stroke-path(circle-pts(R, 96, center: center), stroke: stroke, closed: true, per: 0),
    stroke-path(circle-pts(inner-r, 96, center: center), stroke: stroke, closed: true, per: 0),
    stroke-path(circle-pts(R * 0.16, 32, center: center), stroke: stroke, closed: true, per: 0),
  )
  for i in range(spokes) {
    let angle = 360 * i / spokes
    let a = _add(center, (R * 0.16 * _cos(angle), R * 0.16 * _sin(angle)))
    let b = _add(center, (inner-r * _cos(angle), inner-r * _sin(angle)))
    items.push(stroke-path((a, b), stroke: stroke, closed: false, per: 0))
  }
  _join(items)
  }
}

/// The full L'Hôpital pulley figure: beam, ropes, wheel, weight, labels.
/// `AB`, `l`, `m` in units (fisiko used cm); `k` millimetres per unit.
/// Wood-grain on the beam arrives with the grain milestone — for now the
/// beam is hatched as in figure 5.
#let l-hopital-pulley(AB, l, m, at: (0, 0), k: 6, d1: 2 / 3, d2: 1,
                      rope-w: 3 * _source-min-stroke, seed: 0,
                      length-labels: false) = {
  let G = _pulley-geometry(AB, l, m, d1: d1)
  let to-mm(p) = _add(_mul(p, k), at)
  let A = to-mm(G.A)
  let B = to-mm(G.B)
  let C = to-mm(G.C)
  let D = to-mm(G.D)
  let E = to-mm(G.E)
  let y0 = at.at(1)
  let els = ()

  // Shaded surface band above the ceiling line, as in the upstream figure.
  let bw = 4.0
  els.push(solid-surface(((A.at(0) - bw, y0), (B.at(0) + bw, y0)),
    thickness: -2.5, angle: 45, spacing: 1.5 * _source-spacing))

  // ropes
  els.push(stroke-ink((A, D), rope-w, closed: false, per: 6, seed: seed))
  els.push(stroke-ink((B, D), rope-w, closed: false, per: 6, seed: seed))
  els.push(stroke-ink((D, C), rope-w, closed: false, per: 6, seed: seed))

  // wheel over the kink, then the weight
  let pulley-angle = calc.atan2(A.at(0) - D.at(0), A.at(1) - D.at(1)) / 1deg + 90
  els.push(pulley(d1 * k, center: E, angle: pulley-angle))
  els.push(sphere(d2 * k, seed: seed, center: (C.at(0), C.at(1) + d2 * k / 2)))

  // dots and labels
  let dot(p) = place(top + left, _fill((circle-pts(0.35, 20, center: p),), black))
  els.push(dot(A) + dot(B))
  els.push(tag($A$, (A.at(0) - 2, A.at(1) + 3)))
  els.push(tag($B$, (B.at(0) + 2, B.at(1) + 3)))
  els.push(tag($C$, (C.at(0) - 3, C.at(1) - 2)))
  if length-labels {
  let mid(p, q) = ((p.at(0) + q.at(0)) / 2, (p.at(1) + q.at(1)) / 2)
  let uAD = _unit(_sub(D, A))
  let uBD = _unit(_sub(D, B))
  els.push(tag($l$, _add(mid(A, D), _mul((uAD.at(1), -uAD.at(0)), 2.6))))
  els.push(tag($m$, _add(mid(B, D), _mul((-uBD.at(1), uBD.at(0)), 2.6))))
  }
  _join(els)
}

// ---------------------------------------------------------------------------
// wood grain (fisiko's fig. 16)
// ---------------------------------------------------------------------------

/// Sampled ellipse (radii rx, ry, rotated by `rot` degrees).
#let _ellipse-pts(rx, ry, rot: 0, center: (0, 0), n: 48) = {
  let c = _cos(rot)
  let s = _sin(rot)
  range(n).map(j => {
    let a = 360 * j / n
    let x = rx * _cos(a)
    let y = ry * _sin(a)
    _add(center, (x * c - y * s, x * s + y * c))
  })
}

/// The year-ring field, after fisiko's model: rings are the level sets of
/// parallel planes (spaced `spacing`, running along `angle`), distorted by
/// one log "twig function" per eye — level sets of a logarithm wrap the eye
/// the way real grain wraps a knot.
#let _wood-field(angle, spacing, eyes) = {
  let g = (_cos(angle + 90), _sin(angle + 90))
  (x, y) => {
    let base = (x * g.at(0) + y * g.at(1)) / spacing
    let mut = eyes.fold(0.0, (acc, e) => {
      let s = e.at(2)
      let amp = if e.len() > 3 { e.at(3) } else { 0.9 }
      let sig = s * 0.4
      let r = calc.sqrt(calc.pow(x - e.at(0), 2) + calc.pow(y - e.at(1), 2))
      acc + amp * calc.ln(calc.max(r, sig) / sig)
    })
    base + mut
  }
}

// Source `wField` used by woodBlock, expressed in physical millimetres.
// `source-res` is woodBlockRes; field samples are taken on its grid while the
// geometric contour sampler may use a coarser independent grid.
#let _woodblock-field(w, h, seed, source-res: _source-wood-block-res, rng-offset: 0) = {
  let detail = _source-wood-block-detail
  let knot-radius = _source-wood-knot-radius
  let knot-angle = _source-wood-knot-angle
  let rho = _source-wood-y-density
  // The source default is 1/3 mm (figure drivers may override it); draw one
  // vertical offset per woodBlockRes column, not once per whole millimetre.
  let columns = int(calc.round(w / source-res)) + 1
  let max-knots = calc.max(1, int(calc.ceil(
    w * h / (2 * _source-wood-knot-density))))
  let candidate-cap = calc.max(256, (max-knots + 10) * 30)
  let stream = _metapost-rng-sequence(seed,
    rng-offset + candidate-cap + columns + 2048)
  // Knot coordinates use uniformdeviate's raw fraction through its scaled
  // bound multiplication. Column jitter still uses the quantized stream.
  let raw-stream = _metapost-rng-raw-sequence(seed,
    rng-offset + candidate-cap + columns + 2048)
  let randoms = stream.slice(rng-offset, rng-offset + candidate-cap + columns)
  let knots = ()
  let cursor = 0
  let rejected = 0
  // woodBlock keeps sampling candidates until ten are rejected by the
  // minimum-distance rule; accepted candidates do not consume that counter.
  while rejected < 10 and knots.len() < max-knots and cursor + 1 < candidate-cap {
    // Match the source's fixed-point random-bound product and shifted point.
    let x = _mp-rounded(-knot-radius / 2
      + _mp-rounded((w + knot-radius) * raw-stream.at(rng-offset + cursor)))
    let y = _mp-rounded(-knot-radius / 2
      + _mp-rounded((h + knot-radius) * raw-stream.at(rng-offset + cursor + 1)))
    if knots.all(k => _dist(k, (x, y)) >= _source-wood-knot-density) {
      knots.push((x, y))
      // Each accepted source knot draws five nested brush rings. The pinned
      // MetaPost brush consumes 28 random values for those rings before the
      // next candidate is sampled.
      cursor += 28
    } else { rejected += 1 }
    cursor += 2
  }
  let bd = knot-radius / (2 * source-res) * detail
  let field = (px, py) => {
    let i = px / source-res
    let j = py / source-res
    let column = int(calc.clamp(calc.round(px / source-res), 0, columns - 1))
    let result = 0.0
    for knot in knots {
      let dx = (px - knot.at(0)) * detail / source-res
      let dy = (py - knot.at(1)) * detail / source-res
      let r = calc.sqrt(dx * dx + dy * dy * calc.pow(_sin(knot-angle), 2))
      // MetaPost angleRad uses the field's source-space (x, y) direction.
      let a = calc.atan2(dx, dy)
      if r >= 2 * bd and 0.5 * r - bd < 8 {
        let q = 0.5 * r - bd
        let wave = (calc.sqrt(calc.max(0.0, q)) / calc.pow(3.0, q)) * (_sin(knot-angle) * 0.5 * calc.sin(-a) + 1) * (1 / 3 + 2 / 3 * calc.abs(calc.cos(a)))
        result += wave * wave
      } else if r < 2 * bd {
        result -= 10 * calc.sqrt(calc.max(0.0, 1 - calc.pow(r / (2 * bd), 4)))
      }
      result += calc.cos(2 * calc.pi / 30 * r * 1rad) / 64
    }
    result -= i * rho / 5
    result += calc.sin((calc.pi * i / (w / source-res) +
      4 * calc.pi * j / (h / source-res)) * 1rad) / 32
  // Source draws one uniform vertical displacement per woodBlockRes column,
  // shared by every finer field sample in that column.
    (result + rho / 8 * randoms.at(cursor + column)) / rho
  }
  (field: field, knots: knots, rng-count: cursor + columns)
}

// woodBlock walks its iso-level loop from the sampled field maximum down,
// preserving that maximum's fractional part. Its jitter is added to the
// source field level, so the contour threshold moves in the negative direction.
#let _inside-source-wood-mask(point, poly, inset) = {
  if not _inside-poly(point, poly) { return false }
  if inset <= 0 { return true }
  let nearest = none
  for i in range(poly.len()) {
    let a = poly.at(i)
    let b = poly.at(_mod(i + 1, poly.len()))
    let edge = _sub(b, a)
    let length2 = _dot(edge, edge)
    let t = if length2 == 0 { 0.0 } else {
      calc.clamp(_dot(_sub(point, a), edge) / length2, 0.0, 1.0)
    }
    let distance = _dist(point, _add(a, _mul(edge, t)))
    nearest = if nearest == none { distance }
      else { calc.min(nearest, distance) }
  }
  nearest >= inset - 1e-8
}

#let _wood-source-levels(field, w, h, nx, ny, seed, rng-offset,
                         mask: none) = {
  let values = ()
  for j in range(ny + 1) {
    for i in range(nx + 1) {
      let point = (w * i / nx, h * j / ny)
      if mask == none or mask(point) {
        values.push(field(point.at(0), point.at(1)))
      }
    }
  }
  assert(values.len() > 0, message: "source wood mask contains no field samples")
  let lo = calc.min(..values)
  let hi = calc.max(..values)
  let stream = _metapost-rng-sequence(seed, rng-offset + 32768)
  let levels = ()
  let draw = 0
  let base = hi - 1
  while base > lo {
    levels.push(base - stream.at(rng-offset + draw) / 8)
    draw += 1
    base -= 1
  }
  levels
}

#let _clip-polyline(path, regions) = {
  let out = ()
  let cross(a, b) = a.at(0) * b.at(1) - a.at(1) * b.at(0)
  for i in range(path.len() - 1) {
    let a = path.at(i)
    let b = path.at(i + 1)
    let direction = _sub(b, a)
    let cuts = (0.0, 1.0)
    for poly in regions {
      for j in range(poly.len()) {
        let c = poly.at(j)
        let edge = _sub(poly.at(_mod(j + 1, poly.len())), c)
        let denom = cross(direction, edge)
        if calc.abs(denom) > 0.000000001 {
          let delta = _sub(c, a)
          let t = cross(delta, edge) / denom
          let u = cross(delta, direction) / denom
          if t > 0.000000001 and t < 0.999999999 and u >= -0.000000001 and u <= 1.000000001 {
            cuts.push(t)
          }
        }
      }
    }
    let sorted = cuts.sorted()
    let unique = ()
    for t in sorted {
      if unique.len() == 0 or calc.abs(t - unique.last()) > 0.000000001 {
        unique.push(t)
      }
    }
    for j in range(unique.len() - 1) {
      let t0 = unique.at(j)
      let t1 = unique.at(j + 1)
      if t1 - t0 > 0.000000001 {
        let p = _add(a, _mul(direction, t0))
        let q = _add(a, _mul(direction, t1))
        if regions.any(poly => _inside-poly(_mul(_add(p, q), 0.5), poly)) {
          out.push((p, q))
        }
      }
    }
  }
  out
}

// Like _clip-polyline, but retain connected runs so each contour is stroked
// continuously instead of restarting the pen at every grid edge.
#let _clip-polyline-paths(path, regions) = {
  let out = ()
  let current = ()
  let cross(a, b) = a.at(0) * b.at(1) - a.at(1) * b.at(0)
  for i in range(path.len() - 1) {
    let a = path.at(i)
    let b = path.at(i + 1)
    let direction = _sub(b, a)
    let cuts = (0.0, 1.0)
    for poly in regions {
      for j in range(poly.len()) {
        let c = poly.at(j)
        let edge = _sub(poly.at(_mod(j + 1, poly.len())), c)
        let denom = cross(direction, edge)
        if calc.abs(denom) > 1e-9 {
          let delta = _sub(c, a)
          let t = cross(delta, edge) / denom
          let u = cross(delta, direction) / denom
          if t > 1e-9 and t < 1 - 1e-9 and u >= -1e-9 and u <= 1 + 1e-9 {
            cuts.push(t)
          }
        }
      }
    }
    let sorted = cuts.sorted()
    let unique = ()
    for t in sorted {
      if unique.len() == 0 or calc.abs(t - unique.last()) > 1e-9 {
        unique.push(t)
      }
    }
    for j in range(unique.len() - 1) {
      let t0 = unique.at(j)
      let t1 = unique.at(j + 1)
      if t1 - t0 <= 1e-9 { continue }
      let p = _add(a, _mul(direction, t0))
      let q = _add(a, _mul(direction, t1))
      if regions.any(poly => _inside-poly(_mul(_add(p, q), 0.5), poly)) {
        if current.len() > 0 and _dist(current.last(), p) <= 1e-8 {
          if _dist(current.last(), q) > 1e-8 { current.push(q) }
        } else {
          if current.len() > 1 { out.push(current) }
          current = (p, q)
        }
      } else {
        if current.len() > 1 { out.push(current) }
        current = ()
      }
    }
  }
  if current.len() > 1 { out.push(current) }
  out
}

#let _stroke-segments(segments, stroke) = {
  let segs = ()
  for s in segments {
    segs.push(curve.move(_mm(s.at(0))))
    segs.push(curve.line(_mm(s.at(1))))
  }
  if segs.len() == 0 { none }
  else { place(top + left, curve(fill: none, stroke: stroke, ..segs)) }
}

#let _stroke-paths(paths, stroke) = _join(paths.map(path =>
  stroke-path(path, stroke: stroke, per: 0)))

// Approximate a source-style width profile for a generic contour path.
#let _contour-source-width(field, x, y, w, h, nx, ny, line,
                          value-scale: 1) = {
  let dx = w / nx
  let dy = h / ny
  let fractions = _path-fractions(line, false)
  (t) => {
    let j = range(line.len() - 1).find(i =>
      fractions.at(i) <= t and t <= fractions.at(i + 1))
    let j = if j == none { line.len() - 2 } else { j }
    let span = fractions.at(j + 1) - fractions.at(j)
    let q = if span > 0 { (t - fractions.at(j)) / span } else { 0.0 }
    let p = _add(line.at(j), _mul(_sub(line.at(j + 1), line.at(j)), q))
    let i = int(calc.clamp(calc.floor((p.at(0) - x) / dx), 0, nx - 1))
    let k = int(calc.clamp(calc.floor((p.at(1) - y) / dy), 0, ny - 1))
    let a = field(x + i * dx, y + k * dy)
    let b = field(x + (i + 1) * dx, y + k * dy)
    let c = field(x + (i + 1) * dx, y + (k + 1) * dy)
    let d = field(x + i * dx, y + (k + 1) * dy)
    let variation = (calc.max(a, b, c, d) - calc.min(a, b, c, d)) * value-scale
    (_source-min-stroke / 16) / (1 / 64 + 2 * variation)
  }
}

// Source wood uses brushGenerate(reverse(iL)) with a width template built on
// iL. `source-time` expects the reversed path and samples cell ranges at path
// time knots, including source's terminal unit of width 1.
#let _wood-source-width(field, w, h, nx, ny, line, source-time: false) = {
  let dx = w / nx
  let dy = h / ny
  let fractions = if source-time {
    range(line.len()).map(i => if line.len() > 1 { i / (line.len() - 1) } else { 0.0 })
  } else { _path-fractions(line, false) }
  let cell-ranges = range(line.len() - 1).map(j => {
    let p = _mul(_add(line.at(j), line.at(j + 1)), 0.5)
    if source-time and (p.at(0) < 0 or p.at(0) > w or p.at(1) < 0 or p.at(1) > h) {
      0.0
    } else {
      let i = int(calc.clamp(calc.floor(p.at(0) / dx), 0, nx - 1))
      let k = int(calc.clamp(calc.floor(p.at(1) / dy), 0, ny - 1))
      // woodBlock stores the unscaled field on a 16.16 grid; this helper's
      // field is scaled by 24 for contour-level enumeration. Quantize each
      // corner before taking the range, then preserve source rounding through
      // interpolation and the dimensional offset width below.
      let a = _mp-scalar-rounded(field(i * dx, k * dy) / 24)
      let b = _mp-scalar-rounded(field((i + 1) * dx, k * dy) / 24)
      let c = _mp-scalar-rounded(field((i + 1) * dx, (k + 1) * dy) / 24)
      let d = _mp-scalar-rounded(field(i * dx, (k + 1) * dy) / 24)
      calc.max(a, b, c, d) - calc.min(a, b, c, d)
    }
  })
  let width-values = if source-time {
    cell-ranges.slice(0, calc.max(0, line.len() - 2)) + (1.0, 1.0)
  } else { (1.0,) + cell-ranges }
  (t) => {
    let j = range(line.len() - 1).find(i =>
      fractions.at(i) <= t and t <= fractions.at(i + 1))
    let j = if j == none { line.len() - 2 } else { j }
    let span = fractions.at(j + 1) - fractions.at(j)
    let q = if span > 0 { calc.clamp((t - fractions.at(j)) / span, 0.0, 1.0) } else { 0.0 }
    let variation = width-values.at(j) * (1 - q) + width-values.at(j + 1) * q
    let variation = _mp-scalar-rounded(variation)
    _mp-rounded((_source-min-stroke / 16) / (1 / 64 + 2 * variation))
  }
}

// Rebuild MetaPost's straight offsetPathTemplate q path. Its x coordinate
// advances along the forward source path, while callers may supply a width
// callback whose source cell state follows the reversed brush path.
#let _source-width-q-curves(points, width) = {
  if points.len() < 2 { return () }
  let arcs = (0.0,)
  for i in range(points.len() - 1) {
    arcs.push(arcs.last() + _dist(points.at(i), points.at(i + 1)))
  }
  let knots = range(points.len()).map(i => (
    arcs.at(i), width(float(i) / (points.len() - 1))))
  let line-cubic(a, b) = (
    a,
    (a.at(0) + _mp-rounded((b.at(0) - a.at(0)) / 3),
     a.at(1) + _mp-rounded((b.at(1) - a.at(1)) / 3)),
    (a.at(0) + _mp-rounded(2 * (b.at(0) - a.at(0)) / 3),
     a.at(1) + _mp-rounded(2 * (b.at(1) - a.at(1)) / 3)),
    b,
  )
  range(knots.len() - 1).map(i => line-cubic(
    knots.at(i), knots.at(i + 1)).map(point => (
      int(calc.round(point.at(0) / _mp-unit * 65536)),
      int(calc.round(point.at(1) / _mp-unit * 65536)))))
}

/// Return sampled contour polylines for selected scalar-field levels.
/// `field(x, y)` returns a number; bounds and grid dimensions are in mm and
/// sample counts. The output groups all connected contour paths into one flat
/// array, so it can be inspected, clipped, transformed, or drawn by the caller.
/// Optional `mask(x, y)` excludes grid cells by their physical center.
#let contour-lines(field, x, y, w, h, levels, nx: 40, ny: 24, mask: none) = {
  marching-squares(field, x, y, w, h, levels: levels, nx: nx, ny: ny,
    mask: mask)
}

/// Draw scalar-field isolines at explicit levels using a shared stroke style.
/// Marching-squares segments are stitched into connected polylines first.
/// `mask(x, y)` excludes grid cells by their physical center. Set `width:` to
/// a width in mm, a function of normalized path position returning mm, or
/// `"source"` to use cLine's inverse local-scalar-range width law.
#let iso-lines(field, x, y, w, h, levels, nx: 40, ny: 24,
               stroke: 0.35pt + black, width: none, min-w: _source-min-stroke,
               period: _source-dash-length, seed: 0, fill: black,
               per: 0, mask: none) = {
  let lines = contour-lines(field, x, y, w, h, levels,
    nx: nx, ny: ny, mask: mask)
  _join(lines.enumerate().map(((i, line)) => {
    if width == none { stroke-path(line, stroke: stroke, per: per) }
    else {
      let stroke-width = if type(width) == function { width }
        else if type(width) == str {
          assert(width == "source", message: "width string must be \"source\"")
          _contour-source-width(field, x, y, w, h, nx, ny, line)
        } else { _ => width }
      stroke-ink(line, stroke-width, closed: false, min-w: min-w, period: period,
        seed: seed + i * 104729, per: per, fill: fill)
    }
  }))
}

/// Wood-grain contours clipped to an arbitrary simple polygon. `eyes` use
/// coordinates local to the polygon's bounding box.
#let wooden-thing(poly, angle: 0, spacing: 2.6, eyes: (), cell: 1.0,
                  stroke: 0.45pt + black, source-field: false, seed: 1,
                  grain-stroke: none, contour-brush: "uniform",
                  source-res: _source-wood-block-res, rng-offset: 0, with-rng: false) = {
  assert(contour-brush == "uniform" or contour-brush == "cell-range",
    message: "contour-brush must be uniform or cell-range")
  assert(contour-brush == "uniform" or source-field,
    message: "cell-range contour brush requires source-field")
  if poly.len() < 3 {
    return if with-rng { (none, rng-offset) } else { none }
  }
  let xs = poly.map(p => p.at(0))
  let ys = poly.map(p => p.at(1))
  let x0 = calc.min(..xs)
  let y0 = calc.min(..ys)
  let w = calc.max(..xs) - x0
  let h = calc.max(..ys) - y0
  if w <= 0 or h <= 0 {
    return if with-rng { (none, rng-offset) } else { none }
  }
  let local-poly = poly.map(p => _sub(p, (x0, y0)))
  let nx = calc.max(8, int(calc.ceil(w / cell)))
  let ny = calc.max(8, int(calc.ceil(h / cell)))
  // woodenThing rotates its local outline for a 90° grain angle. woodBlock
  // also swaps wide, landscape blocks internally before drawing their field.
  let turned = source-field and calc.rem(calc.abs(angle), 180) == 90
  let swapped = source-field and (turned or w > h)
  // MetaPost rounds its woodBlock dimensions to woodBlockRes before it
  // samples knots and the field. `source-res` models that source setting.
  let model-w = calc.round((if swapped { h } else { w }) / source-res) * source-res
  let model-h = calc.round((if swapped { w } else { h }) / source-res) * source-res
  let wood-model = if source-field {
    _woodblock-field(model-w, model-h, seed, source-res: source-res,
      rng-offset: rng-offset)
  } else { none }
  let field = if source-field {
    if swapped { (x, y) => (wood-model.field)(model-w - y, x) }
    else { wood-model.field }
  } else { _wood-field(angle, spacing, eyes) }
  let contour-offset = if source-field { rng-offset + wood-model.rng-count } else { 0 }
  let contour-result = if source-field {
    let source-mask = point => {
      _inside-source-wood-mask(point, local-poly, source-res)
    }
    let levels = _wood-source-levels(field, w, h, nx, ny, seed,
      contour-offset, mask: source-mask)
    marching-squares(field, 0, 0, w, h, levels: levels,
      nx: nx, ny: ny, with-count: true, source-walk: true)
  } else {
    (marching-squares(field, 0, 0, w, h, step: 1, nx: nx, ny: ny), 0)
  }
  let contour-stream = if source-field {
    _metapost-rng-sequence(seed, contour-offset + contour-result.at(1) + 32768)
  } else { none }
  let contours = contour-result.at(0)
  let segments = ()
  let source-brushes = ()
  let brush-cursor = contour-offset + contour-result.at(1)
  for contour in contours {
    let clipped = _clip-polyline-paths(contour, (local-poly,))
    for path in clipped {
      if source-field and contour-brush == "cell-range" {
        let brush-path = path.rev()
        let width = _wood-source-width(field, w, h, nx, ny, brush-path,
          source-time: true)
        let source-width-fixed = range(brush-path.len()).map(i =>
          int(calc.round(width(float(i) / (brush-path.len() - 1))
            / _mp-unit * 65536)))
        let drawn = stroke-ink(
          brush-path.map(p => _add(p, (x0, y0))), width,
          closed: false, min-w: _source-min-stroke,
          period: _source-dash-length, seed: seed, per: 0,
          _random-stream: contour-stream, _rng-offset: brush-cursor,
          _with-rng: true, _source-rounding: true, _path-time: true,
          _source-width-fixed: source-width-fixed)
        source-brushes.push(drawn.at(0))
        brush-cursor += drawn.at(1)
      } else { segments.push(path.map(p => _add(p, (x0, y0)))) }
    }
  }
  let explicit-eyes = eyes.filter(e => _inside-poly((e.at(0), e.at(1)), local-poly))
  let source-knots = if source-field {
    if swapped { wood-model.knots.map(k => (k.at(1), model-w - k.at(0))) }
    else { wood-model.knots }
  } else { () }
  let texture-stroke = if source-field {
    if grain-stroke == none { 0.05pt + black } else { grain-stroke + black }
  } else { stroke }
  let border-stroke = if source-field { 0.2pt + black } else { stroke }
  let eye-loops = explicit-eyes.map(e =>
    _ellipse-pts(e.at(2) * 0.6, e.at(2) * 0.38, rot: angle,
                 center: _add((e.at(0), e.at(1)), (x0, y0)))
  )
  let knot-loops = source-knots.map(k => _ellipse-pts(1.25, 1.25 / _sin(60),
    center: _add(k, (x0, y0)), n: 72))
  let knot-segments = ()
  for loop in knot-loops {
    for i in range(loop.len()) {
      knot-segments.push((loop.at(i), loop.at(_mod(i + 1, loop.len()))))
    }
  }
  let els = (_stroke-paths(segments, texture-stroke), ..source-brushes,
             stroke-path(poly, stroke: border-stroke, closed: true, per: 0))
  if eye-loops.len() > 0 { els.push(place(top + left, _fill(eye-loops, black))) }
  if knot-segments.len() > 0 { els.push(_stroke-segments(knot-segments, texture-stroke)) }
  let drawing = _join(els)
  if with-rng {
    (drawing, rng-offset + if source-field {
      wood-model.rng-count + contour-result.at(1)
        + brush-cursor - (contour-offset + contour-result.at(1))
    } else { 0 })
  } else { drawing }
}

/// A plank of wood: iso-lines of the year-ring field, clipped to the
/// rectangle (x, y, w, h), with a dark eye at each knot.
///   * `angle` — grain direction in degrees (0 = horizontal)
///   * `spacing` — distance between rings (mm)
///   * `eyes` — ((x, y, size, amp), ...) in rectangle-local coordinates
/// In `source-field` mode, `rng-offset` on `wooden-thing` or
/// `wooden-surface` resumes the seeded MetaPost stream after earlier objects.
#let wood(x, y, w, h, angle: 0, spacing: 2.6, eyes: (),
          stroke: 0.45pt + black, cell: 1.5, source-field: false, seed: 1,
          contour-brush: "uniform", source-res: _source-wood-block-res) = {
  assert(contour-brush == "uniform" or contour-brush == "cell-range",
    message: "contour-brush must be uniform or cell-range")
  assert(contour-brush == "uniform" or source-field,
    message: "cell-range contour brush requires source-field")
  let nx = calc.max(8, int(calc.round(w / cell)))
  let ny = calc.max(8, int(calc.round(h / cell)))
  let swapped = source-field and w > h
  let model-w = calc.round((if swapped { h } else { w }) / source-res) * source-res
  let model-h = calc.round((if swapped { w } else { h }) / source-res) * source-res
  let model = if source-field {
    _woodblock-field(model-w, model-h, seed, source-res: source-res)
  } else { none }
  let f = if source-field {
    if swapped { (x, y) => (model.field)(model-w - y, x) } else { model.field }
  } else { _wood-field(angle, spacing, eyes) }
  let contour-offset = if source-field { model.rng-count } else { 0 }
  let contour-result = if source-field {
    let levels = _wood-source-levels(f, w, h, nx, ny, seed, contour-offset)
    marching-squares(f, 0, 0, w, h, levels: levels,
      nx: nx, ny: ny, with-count: true)
  } else {
    (marching-squares(f, 0, 0, w, h, step: 1, nx: nx, ny: ny), 0)
  }
  let contour-stream = if source-field {
    _metapost-rng-sequence(seed, contour-offset + contour-result.at(1) + 32768)
  } else { none }
  let loops = contour-result.at(0)
  let rect = ((0, 0), (w, 0), (w, h), (0, h))
  let paths = loops.fold((), (acc, pl) => acc + _clip-polyline-paths(pl, (rect,)))
  let source-brushes = ()
  let brush-cursor = contour-offset + contour-result.at(1)
  if source-field and contour-brush == "cell-range" {
    for path in paths {
      let width = _wood-source-width(f, w, h, nx, ny, path)
      let drawn = stroke-ink(path, width, closed: false,
        min-w: _source-min-stroke, period: _source-dash-length,
        seed: seed, per: 0, _random-stream: contour-stream,
        _rng-offset: brush-cursor, _with-rng: true, _source-rounding: true)
      source-brushes.push(drawn.at(0))
      brush-cursor += drawn.at(1)
    }
  }
  let texture-stroke = if source-field { 0.1pt + black } else { stroke }
  let knot-segments = ()
  if source-field {
    for knot in model.knots.map(k => if swapped { (k.at(1), model-w - k.at(0)) } else { k }) {
      let ring = _ellipse-pts(1.25, 1.25 / _sin(60), center: knot, n: 72)
      for i in range(ring.len()) {
        knot-segments.push((ring.at(i), ring.at(_mod(i + 1, ring.len()))))
      }
    }
  }
  let els = if source-field and contour-brush == "cell-range" { source-brushes }
            else { (_stroke-paths(paths, texture-stroke),) }
  if knot-segments.len() > 0 { els.push(_stroke-segments(knot-segments, texture-stroke)) }
  els += eyes.map(e => place(top + left, _fill(
    (_ellipse-pts(e.at(2) * 0.6, e.at(2) * 0.38, rot: angle,
                  center: (e.at(0), e.at(1))),),
    black,
  )))
  place(top + left, dx: x * 1mm, dy: y * 1mm,
    box(width: w * 1mm, height: h * 1mm, clip: true, _join(els)))
}

/// Wood-grain contours clipped to an offset band along an open path. `eyes`
/// use coordinates local to the band's bounding box, as they do in `wood`.
/// In `source-field` mode, `rng-offset` resumes an earlier seeded draw stream.
#let wooden-surface(path, thickness: 2.5, angle: 0, spacing: 0.7,
                    eyes: (), cell: 1.0, stroke: 0.45pt + black,
                    source-field: true, seed: 1, rng-offset: 0,
                    contour-brush: "uniform") = {
  let outer = resample(path, per: 12, closed: false)
  let inset = offset-path(path, thickness, closed: false)
  let outline = outer + inset.rev()
  if source-field {
    return wooden-thing(outline, angle: angle, spacing: spacing, eyes: eyes,
      cell: cell, stroke: stroke, source-field: true, seed: seed,
      grain-stroke: 0.1pt, contour-brush: contour-brush,
      rng-offset: rng-offset)
  }
  let quads = _band-quads(outer, inset, closed: false)
  let boundary = outer + inset
  let xs = boundary.map(p => p.at(0))
  let ys = boundary.map(p => p.at(1))
  let x0 = calc.min(..xs)
  let y0 = calc.min(..ys)
  let w = calc.max(..xs) - x0
  let h = calc.max(..ys) - y0
  let regions = quads.map(q => q.map(p => _sub(p, (x0, y0))))
  let nx = calc.max(8, int(calc.ceil(w / cell)))
  let ny = calc.max(8, int(calc.ceil(h / cell)))
  let field = _wood-field(angle, spacing, eyes)
  let contours = marching-squares(field, 0, 0, w, h, step: 1, nx: nx, ny: ny)
  let segments = ()
  for contour in contours {
    let clipped = _clip-polyline(contour, regions)
    segments += clipped.map(seg => (_add(seg.at(0), (x0, y0)), _add(seg.at(1), (x0, y0))))
  }
  let outline = outer + inset.rev()
  _join((
    _stroke-segments(segments, stroke),
    stroke-path(outline, stroke: stroke, closed: true, per: 0),
  ))
}

/// Three-dimensional wood block: a grained front face and two shaded sides.
#let wood-block(x, y, w, h, depth: 3, angle: 0, spacing: 2.6,
                eyes: (), stroke: 0.45pt + black) = {
  let front = ((x, y), (x + w, y), (x + w, y + h), (x, y + h))
  let right = ((x + w, y), (x + w + depth, y - depth),
               (x + w + depth, y + h - depth), (x + w, y + h))
  let lower = ((x, y + h), (x + w, y + h),
               (x + w + depth, y + h - depth), (x + depth, y + h - depth))
  _join((
    solid(right, angle: 45, style: "glass", spacing: 0.7, stroke: stroke),
    solid(lower, angle: -45, spacing: 0.7, stroke: stroke),
    wood(x, y, w, h, angle: angle, spacing: spacing, eyes: eyes, stroke: stroke),
    stroke-path(right, stroke: stroke, closed: true, per: 0),
    stroke-path(lower, stroke: stroke, closed: true, per: 0),
    stroke-path(front, stroke: stroke, closed: true, per: 0),
  ))
}

// ---------------------------------------------------------------------------
// physics primitives: arrows, angle marks, springs, lenses, weights
// ---------------------------------------------------------------------------

/// Angle of a direction vector, in screen degrees (y down), as an `angle`.
/// NOTE: empirically `calc.atan2(a, b)` = standard atan2 of the vector (a, b)
/// — i.e. first argument x, second y (verified on four quadrants).
#let _dir-angle(v) = calc.atan2(v.at(0), v.at(1))

/// Arrowhead as a filled triangle: tip at `tip`, pointing along `dir`.
#let _head-pts(tip, dir, size) = {
  let u = _unit(dir)
  let n = (-u.at(1), u.at(0))
  let base = _sub(tip, _mul(u, size))
  let l = _mul(n, size * 0.36)
  (_add(base, l), _sub(base, l), tip)
}

#let _head(tip, dir, size, fill: black) = {
  // must be place-wrapped: raw curves enter the canvas's flow and would
  // displace every following element (and themselves, cumulatively).
  place(top + left, _fill((_head-pts(tip, dir, size),), fill))
}

/// Vector arrow a → b: shaft of width `w` (mm) + filled head at b.
#let vector(a, b, w: 0.5, head: 2.6, fill: black, seed: 0) = {
  let u = _unit(_sub(b, a))
  let stop = _sub(b, _mul(u, head * 0.9))
  _join((
    stroke-ink((a, stop), w, closed: false, per: 4, fill: fill, seed: seed),
    _head(b, u, head, fill: fill),
  ))
}

/// Arc of radius `r` around `o` from ray o+va to ray o+vb (short sweep).
#let _angle-arc(o, va, vb, r: 6) = {
  let th0 = _dir-angle(va)
  let d = _dir-angle(vb) - th0
  let d = if d > 180deg { d - 360deg } else if d < -180deg { d + 360deg } else { d }
  let n = calc.min(72, calc.max(10, int(r * 4)))
  range(n + 1).map(k => {
    let th = th0 + d * (k / n)
    _add(o, (r * calc.cos(th), r * calc.sin(th)))
  })
}

/// Angle mark between rays o→a and o→b: arc at radius `r`, optional ticks.
#let mark-angle(a, o, b, r: 6, ticks: 0, stroke: 0.4pt + black) = {
  let pts = _angle-arc(o, _sub(a, o), _sub(b, o), r: r)
  let els = (stroke-path(pts, stroke: stroke, per: 0),)
  if ticks > 0 {
    let th0 = _dir-angle(_sub(a, o))
    let d0 = _dir-angle(_sub(b, o)) - th0
    let d = if d0 > 180deg { d0 - 360deg } else if d0 < -180deg { d0 + 360deg } else { d0 }
    els += range(ticks).map(i => {
      let th = th0 + d * ((i + 1) / (ticks + 1))
      let dirv = (calc.cos(th), calc.sin(th))
      let p = _add(o, _mul(dirv, r))
      let e = _add(o, _mul(dirv, r + 1.3))
      stroke-path((p, e), stroke: stroke, per: 0)
    })
  }
  _join(els)
}

/// Coil points for a helical spring from a to b (side view of the coil).
#let _spring-pts(a, b, coils: 8, rad: 1.8, lead: 3) = {
  let axis = _sub(b, a)
  let len = _len(axis)
  let u = _unit(axis)
  let n = (-u.at(1), u.at(0))
  let l = calc.min(lead, len * 0.25)
  let body = len - 2 * l
  let steps = coils * 12
  let pts = (a, _add(a, _mul(u, l)))
  for k in range(1, steps) {
    let t = k / steps
    let off = rad * calc.sin(coils * 360 * t * 1deg)
    pts.push(_add(_add(a, _mul(u, l + body * t)), _mul(n, off)))
  }
  pts.push(_add(a, _mul(u, l + body)))
  pts.push(b)
  pts
}

/// Helical spring from a to b (a straight lead, then the coil).
#let spring(a, b, coils: 8, rad: 1.8, lead: 3, stroke: 0.5pt + black) = {
  stroke-path(_spring-pts(a, b, coils: coils, rad: rad, lead: lead),
              stroke: stroke, per: 2)
}

/// Lens outline through the three anchors per side (mm):
/// tips at (∓rim, ±ap/2), centre at (∓sag, 0).
/// rim < sag ⇒ convex, rim > sag ⇒ concave.
#let _lens-outline(ap, sag, rim, per: 8, right-sag: none) = {
  let h = ap / 2
  let rsag = if right-sag == none { sag } else { right-sag }
  let left = resample(((-rim, h), (-sag, 0), (-rim, -h)), per: per, closed: false)
  let right = resample(((rim, h), (rsag, 0), (rim, -h)), per: per, closed: false)
  if rim > 0 {
    left + ((-rim, -h),) + right.rev() + ((rim, h),)
  } else {
    left + right.rev()
  }
}

/// Lens at `at`: outline plus optional dashed optical axis (half-length
/// `axis`).
#let lens(ap, sag, rim: 0.0, right-sag: none, axis: 0, at: (0, 0),
          stroke: 0.5pt + black, per: 8) = {
  let out = _lens-outline(ap, sag, rim, per: per, right-sag: right-sag).map(p => _add(p, at))
  let els = (stroke-path(out, stroke: stroke, closed: true, per: 0),)
  if axis > 0 {
    els.push(stroke-path(((_add(at, (-axis, 0))), _add(at, (axis, 0))),
      stroke: (paint: black, thickness: 0.4pt, dash: "dashed"), per: 0))
  }
  _join(els)
}

/// Segments (top, bottom) of a calibration weight: narrow neck on top of a
/// cylinder, hanging from (0, 0); returns ((a1, b1, r1), (a2, b2, r2)).
#let _weight-parts(h, r, neck: 0.45) = {
  let body-h = h * 0.7
  let n-r = r * neck
  (( (0.0, 0.0), (0.0, h - body-h), n-r ),
   ( (0.0, h - body-h), (0.0, h), r ))
}

/// A hanging weight at `at`: one smooth hatched body with a narrower neck.
#let weight(h, r: 3, neck: 0.25, spacing: _source-spacing, w: 0.45 * pt,
            at: (0, 0), seed: 0) = {
  let auricle-depth = calc.min(2, h / 6)
  let body-height = h - auricle-depth
  let shoulder-length = calc.min(3, body-height)
  let shoulder-end = shoulder-length / body-height
  let body-radius(t) = if t < shoulder-end {
    let u = calc.clamp(t / calc.max(0.000001, shoulder-end), 0.0, 1.0)
    r * (neck + (7 / 8 - neck) * calc.sqrt(calc.max(0.0, 1 - calc.pow(1 - u, 2))))
  } else {
    let u = calc.clamp((t - shoulder-end) / calc.max(0.000001, 1 - shoulder-end), 0.0, 1.0)
    r * (7 / 8 + u / 8)
  }
  let body = tube((_add(at, (0, auricle-depth)), _add(at, (0, h))),
    body-radius, spacing: spacing, w: w, per: 12, seed: seed)
  // Source auricle.d is 2 mm and auricle.t is 2*shadingDensity; the
  // default shadingDensity is 3*(3/2*minStrokeWidth), i.e. 9 min pens.
  let auricle-thickness = 9 * _source-min-stroke
  let auricle-radius = auricle-thickness / 2
  let auricle-length = 1.5 * auricle-thickness
  let auricle-top = range(13).map(i => {
    let a = 180 + 180 * i / 12
    _add(at, (auricle-radius * _cos(a), auricle-radius * _sin(a)))
  })
  let auricle-bottom = range(1, 13).map(i => {
    let a = 180 * i / 12
    _add(at, (auricle-radius * _cos(a), auricle-length + auricle-radius * _sin(a)))
  })
  let auricle-outline = auricle-top + ((_add(at, (auricle-radius, auricle-length)),)
    + auricle-bottom + (_add(at, (-auricle-radius, 0)),))
  let auricle = stroke-path(auricle-outline,
    stroke: _source-min-stroke * 1mm + black, closed: true, per: 0)
  _join((body, auricle))
}

/// A standing weight: broad body rises from its base at `at` to a tapered top.
#let weight-standing(h, r: 3, taper: 0.55, body-fraction: 0.68,
                     spacing: _source-spacing, w: 0.45 * pt,
                     at: (0, 0), seed: 0) = {
  let radius(t) = {
    let u = calc.clamp((t - body-fraction) / (1 - body-fraction), 0.0, 1.0)
    r * (1 - (1 - taper) * u * u * (3 - 2 * u))
  }
  let axis = (_add(at, (0, 0)), _add(at, (0, -h)))
  tube(axis, radius, hatch: "l", spacing: spacing, w: w, per: 12, seed: seed)
}

// ---------------------------------------------------------------------------
// geometric optics
// ---------------------------------------------------------------------------

/// Find the nearest positive ray hit on a closed polygonal boundary.
/// The returned tuple is (distance, point, outward-normal).
#let _ray-hit(origin, direction, boundary) = {
  let area = range(boundary.len()).fold(0.0, (sum, i) => {
    let a = boundary.at(i)
    let b = boundary.at(_mod(i + 1, boundary.len()))
    sum + _cross(a, b)
  }) / 2
  let best = none
  for i in range(boundary.len()) {
    let a = boundary.at(i)
    let b = boundary.at(_mod(i + 1, boundary.len()))
    let edge = _sub(b, a)
    let hit = line-intersect(origin, direction, a, edge)
    if hit != none {
      let t = _dot(_sub(hit, origin), direction)
      let u = _dot(_sub(hit, a), edge) / _dot(edge, edge)
      if t > 1e-5 and u >= -1e-8 and u <= 1 + 1e-8 and (best == none or t < best.at(0)) {
        let tangent = _unit(edge)
        let normal = if area >= 0 { (tangent.at(1), -tangent.at(0)) }
                     else { (-tangent.at(1), tangent.at(0)) }
        best = (t, hit, normal)
      }
    }
  }
  best
}

/// Trace a ray through a closed polygon, reflecting internally on total
/// reflection. `ray` is `(previous-point, current-point)`; `ior` is the
/// refractive index inside the boundary. Returns sampled vertices in mm.
#let trace-refraction(ray, boundary, ior: 1.5, bounces: 8, max-length: 100) = {
  let points = (ray.at(0), ray.at(1))
  let origin = ray.at(1)
  let direction = _unit(_sub(ray.at(1), ray.at(0)))
  let count = 0
  let done = false
  while count < bounces and not done {
    let hit = _ray-hit(origin, direction, boundary)
    if hit == none {
      points.push(_add(origin, _mul(direction, max-length)))
      done = true
    } else {
      let (_, p, outward) = hit
      points.push(p)
      let entering = _dot(direction, outward) < 0
      let normal = if entering { outward } else { _mul(outward, -1) }
      let eta = if entering { 1 / ior } else { ior }
      let cosi = calc.clamp(-_dot(direction, normal), 0.0, 1.0)
      let k = 1 - eta * eta * (1 - cosi * cosi)
      if k < 0 {
        direction = _unit(_add(direction, _mul(normal, 2 * cosi)))
      } else {
        direction = _unit(_add(_mul(direction, eta),
          _mul(normal, eta * cosi - calc.sqrt(k))))
      }
      origin = _add(p, _mul(direction, 1e-5))
      count += 1
    }
  }
  if not done { points.push(_add(origin, _mul(direction, max-length))) }
  points
}

/// Draw a refracted ray through a sampled, closed boundary polygon.
#let refraction-path(ray, boundary, ior: 1.5, bounces: 8,
                     max-length: 100, stroke: 0.45pt + black) = {
  stroke-path(trace-refraction(ray, boundary, ior: ior, bounces: bounces,
                               max-length: max-length), stroke: stroke,
              per: 0)
}

// ---------------------------------------------------------------------------
// globe projection (longitude/latitude in degrees)
// ---------------------------------------------------------------------------

/// Orthographic globe projection; returns (x, y, visible) in unit-radius
/// coordinates. `rotation` is the central longitude and latitude.
#let globe-project(lon, lat, rotation: (0, 0)) = {
  let u = lon - rotation.at(0)
  let lat0 = rotation.at(1)
  let x = _cos(lat) * _sin(u)
  // The pinned MetaPost globe calls pointOnGlobe with longitude + 90° and
  // treats negative horizonOnGlobe values as visible. In this fixture's
  // negated-longitude convention, that places the front hemisphere opposite
  // the usual orthographic longitude-zero view.
  let y = _sin(lat) * _cos(lat0) + _cos(lat) * _cos(u) * _sin(lat0)
  let depth = _sin(lat) * _sin(lat0) - _cos(lat) * _cos(lat0) * _cos(u)
  // Suppress round-off at the exact horizon, so a point on the rim is not
  // alternately classified as visible by tiny trigonometric residuals.
  (x: x, y: y, visible: depth > 1e-10)
}

#let _globe-crossing(a, b, rotation, steps: 14) = {
  let lo = 0.0
  let hi = 1.0
  let av = (globe-project(a.at(0), a.at(1), rotation: rotation)).visible
  for _ in range(steps) {
    let mid = (lo + hi) / 2
    let p = (a.at(0) + (b.at(0) - a.at(0)) * mid,
             a.at(1) + (b.at(1) - a.at(1)) * mid)
    if (globe-project(p.at(0), p.at(1), rotation: rotation)).visible == av {
      lo = mid
    } else {
      hi = mid
    }
  }
  let t = (lo + hi) / 2
  (a.at(0) + (b.at(0) - a.at(0)) * t,
   a.at(1) + (b.at(1) - a.at(1)) * t)
}

#let _globe-densify(coords, max-step: 5) = {
  if coords.len() < 2 or max-step <= 0 { return coords }
  let dense = (coords.at(0),)
  for i in range(1, coords.len()) {
    let a = coords.at(i - 1)
    let b = coords.at(i)
    let steps = calc.max(1, int(calc.ceil(calc.max(
      calc.abs(b.at(0) - a.at(0)), calc.abs(b.at(1) - a.at(1)),
    ) / max-step)))
    for j in range(1, steps + 1) {
      let t = j / steps
      dense.push((a.at(0) + (b.at(0) - a.at(0)) * t,
                  a.at(1) + (b.at(1) - a.at(1)) * t))
    }
  }
  dense
}

#let _globe-visible-paths(coords, rotation, radius, center, crossing-steps: 14) = {
  let paths = ()
  let run = ()
  if coords.len() > 0 and (globe-project(coords.at(0).at(0), coords.at(0).at(1), rotation: rotation)).visible {
    let p = globe-project(coords.at(0).at(0), coords.at(0).at(1), rotation: rotation)
    run.push(_add(center, (radius * p.x, -radius * p.y)))
  }
  for i in range(1, coords.len()) {
    let a = coords.at(i - 1)
    let b = coords.at(i)
    let pa = globe-project(a.at(0), a.at(1), rotation: rotation)
    let pb = globe-project(b.at(0), b.at(1), rotation: rotation)
    if pa.visible and pb.visible {
      if run.len() == 0 { run.push(_add(center, (radius * pa.x, -radius * pa.y))) }
      run.push(_add(center, (radius * pb.x, -radius * pb.y)))
    } else if pa.visible and not pb.visible {
      let h = _globe-crossing(a, b, rotation, steps: crossing-steps)
      let ph = globe-project(h.at(0), h.at(1), rotation: rotation)
      run.push(_add(center, (radius * ph.x, -radius * ph.y)))
      if run.len() > 1 { paths.push(run) }
      run = ()
    } else if not pa.visible and pb.visible {
      let h = _globe-crossing(a, b, rotation, steps: crossing-steps)
      let ph = globe-project(h.at(0), h.at(1), rotation: rotation)
      run = (_add(center, (radius * ph.x, -radius * ph.y)),
             _add(center, (radius * pb.x, -radius * pb.y)))
    }
  }
  if run.len() > 1 { paths.push(run) }
  paths
}

// Reconstruct drawLandMass's closed contour, including the source's horizon
// crossing precision, ordered fullcircle arcs, and arc-conflict resolution.
#let _globe-land-outline-data(coords, rotation, radius, center) = {
  if coords.len() < 3 { return none }
  // drawLandMass walks the source input path as given, then closes only the
  // assembled visible contour with `-- cycle`; do not add a geographic edge
  // from the final input vertex back to the first before horizon clipping.
  let path-coords = coords
  let runs = _globe-visible-paths(path-coords, rotation, radius, center,
    crossing-steps: _source-horizon-crossing-depth)
  if runs.len() == 0 { return none }
  let start-visible = (globe-project(
    path-coords.first().at(0), path-coords.first().at(1),
    rotation: rotation)).visible
  let end-visible = (globe-project(
    path-coords.last().at(0), path-coords.last().at(1),
    rotation: rotation)).visible
  let source-runs-merged = runs.len() > 1 and start-visible and end-visible
  let source-origin-rotated = source-runs-merged or (
    runs.len() == 1 and not start-visible)
  if source-runs-merged {
    // Both cyclic runs carry the explicit polygon endpoint. Keep its repeated
    // knot because the source q template consumes that zero-length path time.
    let merged = runs.last() + runs.first()
    runs = (merged, ..runs.slice(1, runs.len() - 1))
  }
  let rim-time(point) = {
    let initial = _mod(calc.atan2(point.at(0) - center.at(0),
      center.at(1) - point.at(1)) / 45deg, 8)
    let target = ((point.at(0) - center.at(0)) / (2 * radius),
      (center.at(1) - point.at(1)) / (2 * radius))
    let segment = int(calc.floor(_mod(initial - 2, 8)))
    let parameter = _mod(initial - 2, 8)
    for iteration in range(8) {
      let epsilon = 0.00001
      let p = _mp-circle-point(parameter)
      let before = _mp-circle-point(parameter - epsilon)
      let after = _mp-circle-point(parameter + epsilon)
      let derivative = ((after.at(0) - before.at(0)) / (2 * epsilon),
        (after.at(1) - before.at(1)) / (2 * epsilon))
      let residual = (p.at(0) - target.at(0), p.at(1) - target.at(1))
      let delta = (
        (residual.at(0) * derivative.at(0)
          + residual.at(1) * derivative.at(1))
          / (derivative.at(0) * derivative.at(0)
            + derivative.at(1) * derivative.at(1)))
      parameter = calc.clamp(parameter - delta, segment, segment + 1)
    }
    _mod(parameter + 2, 8)
  }
  let arcs = ()
  for i in range(runs.len()) {
    let run = runs.at(i)
    let next = runs.at(_mod(i + 1, runs.len()))
    if _dist(run.last(), next.first()) > 1e-8 {
      let start = rim-time(run.last())
      let raw-end = rim-time(next.first())
      arcs.push((start, if raw-end < start { raw-end + 8 } else { raw-end }))
    } else { arcs.push(none) }
  }
  // Match drawLandMass's conflict rule: if two forward arc intervals cross,
  // advance the later interval's start by one fullcircle turn. A descending
  // pair then intentionally requests a reverse MetaPost subpath.
  for i in range(calc.max(0, arcs.len() - 1)) {
    for j in range(i + 1, arcs.len()) {
      if arcs.at(i) == none or arcs.at(j) == none { continue }
      let conflicts = 0
      for k in (-8, 0, 8) {
        if (arcs.at(j).at(0) > arcs.at(i).at(0) + k and
            arcs.at(j).at(0) < arcs.at(i).at(1) + k) { conflicts += 1 }
        if (arcs.at(i).at(0) > arcs.at(j).at(0) + k and
            arcs.at(i).at(0) < arcs.at(j).at(1) + k) { conflicts += 1 }
      }
      if conflicts > 1 {
        arcs.at(j) = (arcs.at(j).at(0) + 8, arcs.at(j).at(1))
      }
    }
  }
  let outline = ()
  let outline-times = ()
  let circle-time-map = ()
  // Keep q-template arc coordinates independent from outline sampling density.
  let outline-arc-positions = ()
  let closing-arc-length = none
  let path-time = 0.0
  let source-closed-run = runs.len() == 1 and (
    runs.first().len() > 2
    and _dist(runs.first().first(), runs.first().last()) <= 1e-8)
  for i in range(runs.len()) {
    let run = runs.at(i)
    let repeated-close = run.len() > 2 and _dist(run.first(), run.last()) <= 1e-8
    let coast = if repeated-close and not source-closed-run {
      run.slice(0, run.len() - 1)
    } else { run }
    for (j, point) in coast.enumerate() {
      // Keep repeated source vertices inside a coast run: MetaPost's
      // offsetPathTemplate emits a q knot for each path time, even when the
      // centerline has a zero-length segment. Only merge the shared endpoint
      // where a sampled horizon arc joins a coast run.
      if j > 0 or outline.len() == 0 or _dist(outline.last(), point) > 1e-8 {
        let increment = if outline.len() == 0 { 0.0 }
          else { _dist(outline.last(), point) }
        outline.push(point)
        outline-times.push(path-time + j)
        outline-arc-positions.push(if outline-arc-positions.len() == 0 {
          0.0
        } else { outline-arc-positions.last() + increment })
      }
    }
    path-time += calc.max(0, coast.len() - 1)
    let arc = arcs.at(i)
    if arc != none {
      let from = arc.at(0)
      let to = arc.at(1)
      let arc-boundaries = (from,)
      if to > from {
        let boundary = calc.floor(from) + 1
        while boundary < to {
          arc-boundaries.push(boundary)
          boundary += 1
        }
      } else {
        let boundary = calc.ceil(from) - 1
        while boundary > to {
          arc-boundaries.push(boundary)
          boundary -= 1
        }
      }
      arc-boundaries.push(to)
      for (j, boundary) in arc-boundaries.enumerate() {
        circle-time-map.push((time: path-time + j, param: boundary - 2, arc: i))
      }
      let previous-arc-time = from
      for arc-segment-index in range(arc-boundaries.len() - 1) {
        let segment-start = arc-boundaries.at(arc-segment-index)
        let segment-end = arc-boundaries.at(arc-segment-index + 1)
        let steps = int(calc.ceil(calc.abs(segment-end - segment-start) * 16))
        for j in range(steps + 1) {
          if steps == 0 or (arc-segment-index > 0 and j == 0) { continue }
          let t = segment-start + (segment-end - segment-start) * j / steps
          let arc-segment = if t == to { arc-boundaries.len() - 2 } else {
            range(arc-boundaries.len() - 1).find(k =>
              calc.min(arc-boundaries.at(k), arc-boundaries.at(k + 1)) - 1e-10
                <= t and t <= calc.max(arc-boundaries.at(k),
                  arc-boundaries.at(k + 1)) + 1e-10)
          }
          let arc-segment = if arc-segment == none { 0 } else { arc-segment }
          let segment-fraction = (calc.abs(t - arc-boundaries.at(arc-segment)) /
            calc.abs(arc-boundaries.at(arc-segment + 1) -
              arc-boundaries.at(arc-segment)))
          let arc-time = arc-segment + segment-fraction
          // _mp-circle-point is the source cubic fullcircle rotated by 90°.
          let p = _mp-circle-point(t - 2)
          let point = _add(center, (2 * radius * p.at(0), -2 * radius * p.at(1)))
          let subdivisions = 8
          let arc-length = range(subdivisions).map(k => {
            let ta = previous-arc-time + (t - previous-arc-time) * k / subdivisions
            let tb = previous-arc-time + (t - previous-arc-time) * (k + 1) / subdivisions
            let a = _mp-circle-point(ta - 2)
            let b = _mp-circle-point(tb - 2)
            _dist((2 * radius * a.at(0), -2 * radius * a.at(1)),
              (2 * radius * b.at(0), -2 * radius * b.at(1)))
          }).sum()
          if outline.len() == 0 or _dist(outline.last(), point) > 1e-8 {
            outline.push(point)
            outline-times.push(path-time + arc-time)
            outline-arc-positions.push(if outline-arc-positions.len() == 0 {
              0.0
            } else { outline-arc-positions.last() + arc-length })
          } else if (j == steps and outline.len() > 1
              and _dist(point, outline.first()) <= 1e-8) {
            closing-arc-length = arc-length
          }
          previous-arc-time = t
        }
      }
      path-time += arc-boundaries.len() - 1
    }
  }
  // A fully visible closed source contour retains its explicit endpoint and
  // the cyclic terminal knot. The latter shares the endpoint's position and
  // width, but advances the MetaPost path-time once more.
  if source-closed-run { path-time += 1 }
  if outline.len() > 1 {
    let closure = if closing-arc-length == none {
      _dist(outline.last(), outline.first())
    } else { closing-arc-length }
    outline-arc-positions.push(outline-arc-positions.last() + closure)
  }
  if source-origin-rotated and outline.len() > 1 {
    // drawLandMass starts at the first source-visible vertex. For a closed
    // polygon whose input starts hidden, that is the point after the leading
    // horizon-entry sample; with a wrapped visible run, it is the original
    // polygon vertex after merging the last and first runs. Rebase the closed
    // outline there, keeping the cyclic endpoint at the end of source time.
    // Arc positions align with outline points, so source point 1 is at index 1.
    let origin-arc = outline-arc-positions.at(1)
    let total-arc = outline-arc-positions.last()
    let rotated-points = outline.slice(1) + outline.slice(0, 1)
    let rotated-times = outline-times.slice(1).map(t => t - 1) + (path-time,)
    let circle-map-after = circle-time-map.filter(entry => entry.time >= 1)
      .map(entry => (time: entry.time - 1, param: entry.param, arc: entry.arc))
    let circle-map-before = circle-time-map.filter(entry => entry.time < 1)
      .map(entry => (time: entry.time + path-time - 1, param: entry.param, arc: entry.arc))
    circle-time-map = circle-map-after + circle-map-before
    let rotated-arcs = outline-arc-positions.slice(1, outline.len())
      .map(a => a - origin-arc)
    rotated-arcs.push(total-arc - origin-arc)
    rotated-arcs.push(total-arc)
    outline = rotated-points
    outline-times = rotated-times
    outline-arc-positions = rotated-arcs
  }
  // The repeated closed endpoint above already accounts for the cyclic knot;
  // adding another terminal interval would shift later q callback times.
  (points: outline, source-times: outline-times,
    source-circle-time-map: circle-time-map,
    source-arc-positions: outline-arc-positions,
    source-time-end: path-time,
    runs: runs, arcs: arcs)
}

#let _globe-land-outline(coords, rotation, radius, center) = {
  let data = _globe-land-outline-data(coords, rotation, radius, center)
  if data == none { none } else { data.points }
}

#let _globe-land-mask(lands) = (lon, lat) => {
  lands.any(poly => {
    if poly.len() < 3 { false }
    else {
      let mean-lon = poly.fold(0.0, (sum, p) => sum + p.at(0)) / poly.len()
      let unwrapped-lon = lon + 360 * calc.round((mean-lon - lon) / 360)
      _inside-poly((unwrapped-lon, lat), poly)
    }
  })
}

/// Orthographic globe with visible latitude/longitude graticules and optional
/// coast polylines. `lands` is a tuple of polylines, each containing (lon,lat)
/// vertices; `coast-step:` controls geographic subdivision before hidden
/// portions are clipped at the horizon. Set it to `0` to project and connect
/// only the supplied vertices, matching MetaPost's polygonal land paths.
#let globe(d, rotation: (0, 0), lands: (), parallels: 30, meridians: 30,
          shading: "graticule", shading-spacing: _source-spacing,
          shading-width: _source-max-shading, shading-gamma: 0.0,
          coast-step: 5, seed: 1,
          light: (-0.353553, 0.382683, 0.853553),
          center: (0, 0), stroke: 0.4pt + black, outline: 0.6pt + black,
          _trace-coasts: false) = {
  let radius = d / 2
  let light-length = calc.sqrt(light.at(0) * light.at(0)
    + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let light-dir = light.map(v => v / light-length)
  assert(shading == "graticule" or shading == "latitude",
    message: "globe shading must be graticule or latitude")
  let graticule-lines = ()
  if shading == "graticule" and parallels > 0 {
    for k in range(calc.max(0, int(calc.ceil(180 / parallels)) - 1)) {
      let lat = -90 + (k + 1) * parallels
      let geo = range(73).map(i => (-180 + i * 5, lat))
      graticule-lines += _globe-visible-paths(geo, rotation, radius, center)
    }
  }
  if shading == "graticule" and meridians > 0 {
    for k in range(int(calc.ceil(360 / meridians))) {
      let lon = k * meridians
      let geo = range(37).map(i => (lon, -90 + i * 5))
      graticule-lines += _globe-visible-paths(geo, rotation, radius, center)
    }
  }
  let coast-lines = ()
  let coast-landmass-ids = ()
  let coast-param-times = ()
  let coast-param-arcs = ()
  let coast-param-ends = ()
  for (land-index, land) in lands.enumerate() {
    if shading == "latitude" {
      let data = _globe-land-outline-data(
        _globe-densify(land, max-step: coast-step), rotation, radius, center)
      if data != none {
        coast-lines += (data.points,)
        coast-landmass-ids.push(land-index + 1)
        coast-param-times.push(data.source-times)
        coast-param-arcs.push(data.source-arc-positions)
        coast-param-ends.push(data.source-time-end)
      }
    } else {
      coast-lines += _globe-visible-paths(
        _globe-densify(land, max-step: coast-step), rotation, radius, center)
    }
  }
  let elements = graticule-lines.map(path => stroke-path(path, stroke: stroke, per: 0))
  let coast-results = coast-lines.enumerate().map(((i, path)) => {
    if shading != "latitude" {
      (drawing: stroke-path(path, stroke: stroke, per: 0), trace: none)
    } else {
      let fractions = _path-fractions(path, true)
      let width(t) = {
        let j = range(path.len()).find(j => {
          let end = if j + 1 < path.len() { fractions.at(j + 1) } else { 1.0 }
          fractions.at(j) <= t and t <= end
        })
        let j = if j == none { path.len() - 1 } else { j }
        let next = _mod(j + 1, path.len())
        let end = if next == 0 { 1.0 } else { fractions.at(next) }
        let span = end - fractions.at(j)
        let q = if span > 0 { (t - fractions.at(j)) / span } else { 0.0 }
        let point = _add(path.at(j), _mul(_sub(path.at(next), path.at(j)), q))
        let local = _sub(point, center)
        // source sphereAnglesToNormalVector uses asin(abs(point) / 2s);
        // here d == 2s, so the normal's horizontal radius is |point| / d.
        let radial = calc.min(0.999999, _len(local) / d)
        // Typst's atan2 takes (x, y), unlike the usual atan2(y, x) notation.
        let angle = calc.atan2(local.at(0), -local.at(1)) / 1deg
        // Match sphereAnglesToNormalVector and normalVectorToLightness for
        // the coast point, including the source's azimuthal light direction.
        let normal = (radial * _cos(angle), radial * _sin(angle),
          calc.sqrt(calc.max(0.0, 1 - radial * radial)))
        let lam = normal.at(0) * light-dir.at(0) + normal.at(1) * light-dir.at(1) + normal.at(2) * light-dir.at(2)
        let lightness = calc.clamp(1 - lam, 0.0, 1.0)
        _source-min-stroke * (2 / 3 + lightness / 3)
      }
      let source-width-fixed = {
        let times = coast-param-times.at(i)
        let start-time = times.first()
        let end-time = coast-param-ends.at(i)
        let count = int(calc.round(end-time - start-time))
        range(count + 1).map(offset => {
          let source-time = start-time + offset
          let segment = if source-time >= times.last() {
            path.len() - 1
          } else {
            range(path.len() - 1).find(j =>
              times.at(j) <= source-time and source-time <= times.at(j + 1))
          }
          let segment = if segment == none { path.len() - 1 } else { segment }
          let segment-end = if segment + 1 < path.len() {
            times.at(segment + 1)
          } else { end-time }
          let span = segment-end - times.at(segment)
          let fraction = if span > 0 {
            calc.clamp((source-time - times.at(segment)) / span, 0.0, 1.0)
          } else { 0.0 }
          let t = if source-time >= end-time {
            0.0
          } else if segment + 1 < path.len() {
            fractions.at(segment) + fraction * (fractions.at(segment + 1) - fractions.at(segment))
          } else {
            fractions.at(segment) + fraction * (1 - fractions.at(segment))
          }
          int(calc.round(width(t) / _mp-unit * 65536))
        })
      }
      let result = stroke-ink(path, width, closed: true, per: 0,
        min-w: _source-min-stroke, period: _source-dash-length,
        seed: seed + i * 104729,
        _with-rng: _trace-coasts, _with-stats: _trace-coasts,
        _trace-nodes: _trace-coasts, _source-rounding: true,
        _param-times: coast-param-times.at(i),
        _param-end: coast-param-ends.at(i),
        _source-width-fixed: source-width-fixed,
        _source-arc-positions: coast-param-arcs.at(i))
      if _trace-coasts {
        let trace-samples = range(result.at(3).times.len()).map(j => (
          arc: result.at(3).times.at(j) * result.at(2).nodes.at(0).length,
          point: result.at(3).points.at(j), width: result.at(3).widths.at(j)))
        (drawing: result.at(0), trace: (
          landmass: coast-landmass-ids.at(i), points: path.len(),
          calls: result.at(1), outer: result.at(2).outer,
          thin: result.at(2).thin, dashes: result.at(2).dashes,
          nodes: result.at(2).nodes, width-samples: trace-samples,
          outline-points: path,
          source-times: coast-param-times.at(i),
          source-time-end: coast-param-ends.at(i),
          source-arc-positions: coast-param-arcs.at(i),
          source-width-fixed: source-width-fixed))
      } else { (drawing: result, trace: none) }
    }
  })
  let coast-elements = coast-results.map(item => item.drawing)
  let coast-traces = coast-results.filter(item => item.trace != none)
    .map(item => item.trace)
  let drawing = if shading == "latitude" {
    if lands.len() == 0 {
      let latitude-lines = sphere-latitude(d, latitude: rotation.at(1),
        spacing: shading-spacing, max-w: shading-width, gamma: shading-gamma,
        light: light, center: center, outline: true)
      _join((latitude-lines, ..elements))
    } else {
      let is-land = _globe-land-mask(lands)
      // The source constructs p1 (ocean) before p2 (land), then draws p2,
      // coast brushes, and the inverse-masked p1 in that visual order.
      let ocean = sphere-latitude(d, latitude: rotation.at(1),
        spacing: shading-spacing, max-w: 0.85 * shading-width,
        gamma: shading-gamma, light: light, center: center, outline: false,
        seed: seed, rng: "metapost",
        surface-mask: (lon, lat) => not is-land(lon, lat),
        mask-rotation: rotation, with-rng: true)
      let land = sphere-latitude(d, latitude: rotation.at(1),
        spacing: shading-spacing, max-w: 1.28 * shading-width,
        gamma: shading-gamma, light: light, center: center, outline: false,
        seed: seed, rng: "metapost", rng-offset: ocean.at(1),
        surface-mask: is-land, mask-rotation: rotation, with-rng: true)
      _join((land.at(0), ..elements, ..coast-elements, ocean.at(0),
        stroke-path(circle-pts(radius, 180, center: center),
          stroke: outline, closed: true, per: 0)))
    }
  } else {
    elements += coast-elements
    elements.push(stroke-path(circle-pts(radius, 180, center: center),
                              stroke: outline, closed: true, per: 0))
    _join(elements)
  }
  if _trace-coasts {
    [#metadata(coast-traces) <m11-coast-brush-trace> #drawing]
  } else { drawing }
}

// ---------------------------------------------------------------------------
// anatomical eye
// ---------------------------------------------------------------------------

/// Draw a stylized eye. `size` is (width, height), `look` ranges roughly
/// from -1 to 1 in each direction, and `rotation` is in screen degrees.
/// Lash placement is deterministic for a given seed.
#let eye(at: (0, 0), size: (22, 11), look: (0.25, 0), rotation: 0,
        lashes: 7, seed: 0, stroke: 0.45pt + black) = {
  let w = size.at(0)
  let h = size.at(1)
  let c = _cos(rotation)
  let s = _sin(rotation)
  let tx(p) = _add(at, (p.at(0) * c - p.at(1) * s,
                        p.at(0) * s + p.at(1) * c))
  let upper = range(33).map(i => {
    let t = i / 32
    let x = w * (t - 0.5)
    (x, -h * 0.5 * calc.pow(_sin(180 * t), 0.72))
  })
  let lower = range(33).map(i => {
    let t = i / 32
    let x = w * (t - 0.5)
    (x, h * 0.5 * calc.pow(_sin(180 * t), 0.78))
  })
  let iris-center = (calc.clamp(look.at(0), -1.0, 1.0) * w * 0.14,
                     calc.clamp(look.at(1), -1.0, 1.0) * h * 0.14)
  let outline = upper + lower.rev()
  let elements = (
    place(top + left, _fill((outline.map(tx),), white)),
    stroke-path(upper.map(tx), stroke: stroke, per: 0),
    stroke-path(lower.map(tx), stroke: stroke, per: 0),
  )
  elements.push(place(top + left,
    _fill((circle-pts(h * 0.29, 48, center: tx(iris-center)),), black)))
  elements.push(place(top + left,
    _fill((circle-pts(h * 0.20, 48, center: tx(iris-center)),), white)))
  elements.push(place(top + left,
    _fill((circle-pts(h * 0.12, 40, center: tx(iris-center)),), black)))
  elements.push(place(top + left,
    _fill((circle-pts(h * 0.035, 20,
      center: tx(_add(iris-center, (-h * 0.045, -h * 0.055)))),), white)))
  for i in range(lashes) {
    let t = (i + 1) / (lashes + 1)
    let idx = int(calc.round(t * (upper.len() - 1)))
    let base = upper.at(idx)
    let jitter = _rng(seed, i + 1, 7) - 0.5
    let tip = (base.at(0) + (t - 0.5) * h * 0.18,
               base.at(1) - h * (0.20 + 0.07 * jitter))
    elements.push(stroke-path((tx(base), tx(tip)), stroke: stroke, per: 0))
  }
  _join(elements)
}

// ---------------------------------------------------------------------------
// crossing-aware strand knots
// ---------------------------------------------------------------------------

#let _polyline-lengths(points) = {
  let lengths = (0.0,)
  let total = 0.0
  for i in range(1, points.len()) {
    total += _dist(points.at(i - 1), points.at(i))
    lengths.push(total)
  }
  lengths
}

#let _polyline-point(points, lengths, distance) = {
  let k = range(points.len() - 1).find(i => lengths.at(i + 1) >= distance)
  let i = if k == none { points.len() - 2 } else { k }
  let span = lengths.at(i + 1) - lengths.at(i)
  let t = if span > 0 { calc.clamp((distance - lengths.at(i)) / span, 0.0, 1.0) } else { 0.0 }
  _add(points.at(i), _mul(_sub(points.at(i + 1), points.at(i)), t))
}

#let _polyline-window(points, lengths, center, half-width) = {
  let total = lengths.last()
  let lo = calc.max(0.0, center - half-width)
  let hi = calc.min(total, center + half-width)
  let result = (_polyline-point(points, lengths, lo),)
  for i in range(points.len()) {
    if lengths.at(i) > lo + 1e-6 and lengths.at(i) < hi - 1e-6 {
      result.push(points.at(i))
    }
  }
  if hi > lo + 1e-6 { result.push(_polyline-point(points, lengths, hi)) }
  result
}

#let _polyline-time-point(points, times, time) = {
  let k = range(points.len() - 1).find(i => times.at(i + 1) >= time)
  let i = if k == none { points.len() - 2 } else { k }
  let span = times.at(i + 1) - times.at(i)
  let f = if span > 0 { calc.clamp((time - times.at(i)) / span, 0.0, 1.0) } else { 0.0 }
  _add(points.at(i), _mul(_sub(points.at(i + 1), points.at(i)), f))
}

#let _polyline-time-range(points, times, start, finish) = {
  let out = (_polyline-time-point(points, times, start),)
  for i in range(points.len()) {
    if times.at(i) > start + 1e-8 and times.at(i) < finish - 1e-8 {
      out.push(points.at(i))
    }
  }
  if finish > start + 1e-8 { out.push(_polyline-time-point(points, times, finish)) }
  out
}

#let _sort-crossings(events) = {
  let sorted = ()
  for e in events {
    let inserted = false
    let next = ()
    for old in sorted {
      if not inserted and e.at(0) < old.at(0) {
        next.push(e)
        inserted = true
      }
      next.push(old)
    }
    if not inserted { next.push(e) }
    sorted = next
  }
  sorted
}

#let _source-layer-value(value, index) = {
  if type(value) != array { return value }
  if index >= value.len() { return 0 }
  value.at(index)
}

#let _strand-fragments(points, lengths, events) = {
  let sorted = _sort-crossings(events)
  let total = lengths.at(lengths.len() - 1)
  let result = ()
  let cursor = 0.0
  for event in sorted {
    let left = calc.max(cursor, event.at(0) - event.at(1))
    let right = calc.min(total, event.at(0) + event.at(1))
    if left > cursor + 1e-6 {
      let part = (_polyline-point(points, lengths, cursor),)
      for i in range(points.len()) {
        if lengths.at(i) > cursor + 1e-6 and lengths.at(i) < left - 1e-6 {
          part.push(points.at(i))
        }
      }
      part.push(_polyline-point(points, lengths, left))
      if part.len() > 1 { result.push((path: part, range: (cursor, left))) }
    }
    cursor = calc.max(cursor, right)
  }
  if total > cursor + 1e-6 {
    let part = (_polyline-point(points, lengths, cursor),)
    for i in range(points.len()) {
      if lengths.at(i) > cursor + 1e-6 and lengths.at(i) < total - 1e-6 {
        part.push(points.at(i))
      }
    }
    part.push(points.at(points.len() - 1))
    if part.len() > 1 { result.push((path: part, range: (cursor, total))) }
  }
  result
}

// Reconstruct a tube's closed outer contour for source-style planar lighting
// shadows. The returned points use the same screen-space coordinates as tube.
#let _tube-shadow-plane(pts, radius, depth, source-cubic-step: 0) = {
  let layout = _tube-layout(pts, radius, hatch: "none", per: 12,
    source-cubic-step: source-cubic-step)
  (polygon: layout.silhouette, depth: depth)
}

#let _polygon-edge-grid(polygon) = {
  if polygon.len() < 3 { return none }
  // Index polygon edges into a uniform grid so each path segment checks only
  // nearby edges. Strand shadow silhouettes can have hundreds of edges, so
  // scanning every edge for every path segment wastes work on distant pairs.
  let min-x = calc.min(..polygon.map(point => point.at(0)))
  let max-x = calc.max(..polygon.map(point => point.at(0)))
  let min-y = calc.min(..polygon.map(point => point.at(1)))
  let max-y = calc.max(..polygon.map(point => point.at(1)))
  let grid-size = calc.max(1, int(calc.ceil(calc.sqrt(polygon.len()))))
  let x-cell(x) = if max-x > min-x {
    int(calc.clamp(calc.floor((x - min-x) / (max-x - min-x) * grid-size),
      0, grid-size - 1))
  } else { 0 }
  let y-cell(y) = if max-y > min-y {
    int(calc.clamp(calc.floor((y - min-y) / (max-y - min-y) * grid-size),
      0, grid-size - 1))
  } else { 0 }
  let edge-grid = range(grid-size).map(_ => range(grid-size).map(_ => ()))
  for j in range(polygon.len()) {
    let a = polygon.at(j)
    let b = polygon.at(_mod(j + 1, polygon.len()))
    for iy in range(y-cell(calc.min(a.at(1), b.at(1))),
        y-cell(calc.max(a.at(1), b.at(1))) + 1) {
      for ix in range(x-cell(calc.min(a.at(0), b.at(0))),
          x-cell(calc.max(a.at(0), b.at(0))) + 1) {
        edge-grid.at(iy).at(ix).push(j)
      }
    }
  }
  (min-x: min-x, max-x: max-x, min-y: min-y, max-y: max-y,
    grid-size: grid-size, edge-grid: edge-grid)
}
#let _path-polygon-crossings(path, polygon, index: none, shift: (0, 0)) = {
  if path.len() < 2 or polygon.len() < 3 { return () }
  let edge-index = if index == none { _polygon-edge-grid(polygon) } else { index }
  // Translation preserves the edge-to-cell assignment. Shift the grid bounds
  // and edge coordinates while reusing the original cell lists; shadowCut
  // translates the same occluder outline separately for each tube lane.
  let min-x = edge-index.min-x + shift.at(0)
  let max-x = edge-index.max-x + shift.at(0)
  let min-y = edge-index.min-y + shift.at(1)
  let max-y = edge-index.max-y + shift.at(1)
  let grid-size = edge-index.grid-size
  let edge-grid = edge-index.edge-grid
  let x-cell(x) = if max-x > min-x {
    int(calc.clamp(calc.floor((x - min-x) / (max-x - min-x) * grid-size),
      0, grid-size - 1))
  } else { 0 }
  let y-cell(y) = if max-y > min-y {
    int(calc.clamp(calc.floor((y - min-y) / (max-y - min-y) * grid-size),
      0, grid-size - 1))
  } else { 0 }
  let crossings = ()
  for i in range(path.len() - 1) {
    let a = path.at(i)
    let next = path.at(i + 1)
    let da = _sub(next, a)
    let candidates = ()
    let segment-crossings = ()
    for iy in range(y-cell(calc.min(a.at(1), next.at(1))),
        y-cell(calc.max(a.at(1), next.at(1))) + 1) {
      for ix in range(x-cell(calc.min(a.at(0), next.at(0))),
          x-cell(calc.max(a.at(0), next.at(0))) + 1) {
        for j in edge-grid.at(iy).at(ix) {
          if not candidates.contains(j) { candidates.push(j) }
        }
      }
    }
    for j in candidates {
      let b = _add(polygon.at(j), shift)
      let next-b = _add(polygon.at(_mod(j + 1, polygon.len())), shift)
      let db = _sub(next-b, b)
      let point = line-intersect(a, da, b, db)
      if point != none and _len(da) > 0 and _len(db) > 0 {
        let ta = _dot(_sub(point, a), da) / _dot(da, da)
        let tb = _dot(_sub(point, b), db) / _dot(db, db)
        if (ta >= -1e-6 and ta <= 1 + 1e-6
          and tb >= -1e-6 and tb <= 1 + 1e-6) {
          segment-crossings.push((ta, j, tb, point))
        }
      }
    }
    for (ta, j, tb, point) in segment-crossings.sorted() {
      let duplicate = crossings.any(event => {
        let same-segment = (event.at("path-segment") == i and
          calc.abs(event.at("path-fraction") - ta) <= 1e-8)
        let same-vertex = (event.at("path-segment") + 1 == i and
          event.at("path-fraction") >= 1 - 1e-8 and ta <= 1e-8 and
          _dist(event.at("point"), point) <= 1e-8)
        same-segment or same-vertex
      })
      if not duplicate {
        crossings.push((path-segment: i, path-fraction: ta,
          polygon-edge: j, polygon-fraction: tb,
          polygon-segment-time: j + tb, point: point))
      }
    }
  }
  crossings
}
#let _path-intersects-polygon(path, polygon, index: none) = {
  if polygon.len() < 3 { return false }
  let edge-index = if index == none { _polygon-edge-grid(polygon) } else { index }
  if path.any(point => _inside-poly-indexed(point, polygon, edge-index)) {
    return true
  }
  if path.len() < 2 { return false }
  if _path-polygon-crossings(path, polygon, index: edge-index).len() > 0 {
    return true
  }
  false
}

/// Draw sampled strands with real over/under gaps at their intersections.
/// `strands` is a tuple of open polylines. By default, crossings between each
/// strand pair alternate over/under in traversal order. `layers` accepts either
/// one numeric global rank per strand or a per-strand sequence of ranks for
/// successive crossings; ranks beyond that sequence default to layer zero,
/// matching the source's `intLayers` fallback. `widths` may be one value for
/// all strands or a tuple with one value per strand; values are stroke widths
/// for `style: "stroke"`
/// and tube radii for `style: "tube"`. `gap` adds clearance beyond the visible
/// width or diameter at an over-under crossing. In tube style, the hidden
/// interval expands by the crossing angle to match the projection of the
/// over-strand tube onto the under-strand path.
/// Set `occlusion: "mask"` with tube style to split strands at crossing
/// midpoints, order the segments by layer, and mask lower tubes with higher
/// silhouettes. `path-times:` can map samples to source path parameters. The
/// default `"gap"` mode physically removes the under-strand interval. In tube
/// mask mode, `rng: "metapost"` and `rng-offset:` opt into one shared stream
/// across the source-ordered segment renders; keyed randomness remains default.
/// `source-cubic-step:` optionally reconstructs centerline cubics from
/// equally spaced samples, using the same interval meaning as `tube`.
/// Each entry in `widths:` may be a constant or a callback of normalized
/// whole-strand arc length; callback positions remain continuous across
/// fragments created by crossing gaps or masks.
#let strand-knot(strands, widths: 1.25, layers: auto, path-times: none, gap: 0.6,
                 self-crossings: true, seed: 0, stroke: black,
                 style: "stroke", occlusion: "gap", rng: "keyed", rng-offset: 0,
                 source-cubic-step: 0) = {
  assert(style == "stroke" or style == "tube",
    message: "strand-knot style must be stroke or tube")
  assert(occlusion == "gap" or occlusion == "mask",
    message: "strand-knot occlusion must be gap or mask")
  assert(rng == "keyed" or rng == "metapost",
    message: "strand-knot rng must be keyed or metapost")
  assert(rng != "metapost" or (style == "tube" and occlusion == "mask"),
    message: "strand-knot rng: metapost currently requires tube mask mode")
  let n = strands.len()
  let lengths = strands.map(_polyline-lengths)
  let path-times = if path-times == none {
    strands.map(path => range(path.len()).map(i => float(i)))
  } else { path-times }
  assert(path-times.len() == n and range(n).all(i =>
    path-times.at(i).len() == strands.at(i).len()),
    message: "path-times must provide one parameter for every strand point")
  assert(range(n).all(si => range(strands.at(si).len() - 1).all(pi =>
    path-times.at(si).at(pi + 1) > path-times.at(si).at(pi))),
    message: "path-times must increase strictly along each strand")
  let widths = if type(widths) == array { widths } else { range(n).map(_ => widths) }
  let width-at-distance(strand-index, distance) = {
    let total = lengths.at(strand-index).last()
    let t = if total > 0 { calc.clamp(distance / total, 0.0, 1.0) } else { 0.0 }
    _val(widths.at(strand-index), t)
  }
  let distance-at-time(strand-index, source-time) = {
    let times = path-times.at(strand-index)
    let cumulative = lengths.at(strand-index)
    if source-time <= times.first() { return 0.0 }
    if source-time >= times.last() { return cumulative.last() }
    for segment in range(times.len() - 1) {
      if times.at(segment) <= source-time and source-time <= times.at(segment + 1) {
        let fraction = ((source-time - times.at(segment)) /
          (times.at(segment + 1) - times.at(segment)))
        return cumulative.at(segment) * (1 - fraction)
          + cumulative.at(segment + 1) * fraction
      }
    }
    cumulative.last()
  }
  let width-over-distance-range(strand-index, distance-range) = {
    let width = widths.at(strand-index)
    if type(width) != function { return width }
    let total = lengths.at(strand-index).last()
    let start-distance = distance-range.at(0)
    let finish-distance = distance-range.at(1)
    (local-time) => {
      let distance = (start-distance + calc.clamp(local-time, 0.0, 1.0)
        * (finish-distance - start-distance))
      let source-time = if total > 0 { calc.clamp(distance / total, 0.0, 1.0) } else { 0.0 }
      _val(width, source-time)
    }
  }
  let segment-width(strand-index, source-time-range) = width-over-distance-range(
    strand-index, (
      distance-at-time(strand-index, source-time-range.at(0)),
      distance-at-time(strand-index, source-time-range.at(1))))
  let crossing-time(time) = if source-cubic-step > 0 {
    // knotFromStrands stores crossings as round(time * 10) / 10 before it
    // sorts them and cuts the strand into layer segments.
    calc.round(time * 10) / 10
  } else { time }
  let crossing-half-gap(width, crossing-sine: 1.0) = if style == "tube" {
    width / calc.max(0.1, crossing-sine) + gap / 2
  } else { (width + gap) / 2 }
  // A strand may carry a sequence of source `intLayers` values, one for each
  // successive crossing interval. Scalar entries retain the simpler global
  // per-strand ordering accepted by the original Typst API.
  let over-at(pair-count, strand-index, other-index) = {
    if layers == auto or strand-index == other-index { _mod(pair-count, 2) == 0 }
    else {
      let own = layers.at(strand-index)
      let other = layers.at(other-index)
      let own-level = _source-layer-value(own, pair-count)
      let other-level = _source-layer-value(other, pair-count)
      own-level >= other-level
    }
  }
  let layer-rank(strand-index, crossing-index, is-over) = {
    if layers == auto { if is-over { 1 } else { 0 } }
    else {
      let own = layers.at(strand-index)
      _source-layer-value(own, crossing-index)
    }
  }
  let events = range(n).map(_ => ())
  let strand-crossings = range(n).map(_ => ())
  let crossing-counts = range(n).map(_ => 0)
  for i in range(n) {
    for j in range(i + 1, n) {
      let pair-count = 0
      let a = strands.at(i)
      let b = strands.at(j)
      for ai in range(a.len() - 1) {
        if _dist(a.at(ai), a.at(ai + 1)) < 1e-9 { continue }
        let da = _sub(a.at(ai + 1), a.at(ai))
        for bi in range(b.len() - 1) {
          if _dist(b.at(bi), b.at(bi + 1)) < 1e-9 { continue }
          let db = _sub(b.at(bi + 1), b.at(bi))
          let p = line-intersect(a.at(ai), da, b.at(bi), db)
          if p != none {
            let ta = _dot(_sub(p, a.at(ai)), da) / _dot(da, da)
            let tb = _dot(_sub(p, b.at(bi)), db) / _dot(db, db)
            // Include segment starts and exclude ends so a crossing exactly
            // on a polyline vertex is counted once, by its outgoing segment.
            if ta >= -1e-6 and ta < 1 - 1e-6 and tb >= -1e-6 and tb < 1 - 1e-6 {
              let sa = lengths.at(i).at(ai) + ta * _dist(a.at(ai), a.at(ai + 1))
              let sb = lengths.at(j).at(bi) + tb * _dist(b.at(bi), b.at(bi + 1))
              let ta-time = crossing-time(path-times.at(i).at(ai) * (1 - ta) + path-times.at(i).at(ai + 1) * ta)
              let tb-time = crossing-time(path-times.at(j).at(bi) * (1 - tb) + path-times.at(j).at(bi + 1) * tb)
              let enda = lengths.at(i).at(lengths.at(i).len() - 1)
              let endb = lengths.at(j).at(lengths.at(j).len() - 1)
              if sa <= 1e-5 or sa >= enda - 1e-5 or sb <= 1e-5 or sb >= endb - 1e-5 {
                continue
              }
              let crossing-sine = calc.abs(_cross(da, db)) / (_len(da) * _len(db))
              let i-over = over-at(pair-count, i, j)
              strand-crossings.at(i).push((ta-time,
                layer-rank(i, crossing-counts.at(i), i-over)))
              strand-crossings.at(j).push((tb-time,
                layer-rank(j, crossing-counts.at(j), not i-over)))
              crossing-counts.at(i) += 1
              crossing-counts.at(j) += 1
              if i-over {
                events.at(j).push((sb, crossing-half-gap(
                  width-at-distance(i, sa),
                  crossing-sine: crossing-sine)))
              } else {
                events.at(i).push((sa, crossing-half-gap(
                  width-at-distance(j, sb),
                  crossing-sine: crossing-sine)))
              }
              pair-count += 1
            }
          }
        }
      }
    }
  }
  if self-crossings {
    for i in range(n) {
      let path = strands.at(i)
      let pair-count = 0
      let closed = path.at(0) == path.at(path.len() - 1)
      for ai in range(path.len() - 1) {
        if _dist(path.at(ai), path.at(ai + 1)) < 1e-9 { continue }
        let da = _sub(path.at(ai + 1), path.at(ai))
        for bi in range(ai + 2, path.len() - 1) {
          if _dist(path.at(bi), path.at(bi + 1)) < 1e-9 { continue }
          let adjacent-seam = closed and ai == 0 and bi == path.len() - 2
          let db = _sub(path.at(bi + 1), path.at(bi))
          let p = if adjacent-seam { none }
                  else { line-intersect(path.at(ai), da, path.at(bi), db) }
          if p != none {
            let ta = _dot(_sub(p, path.at(ai)), da) / _dot(da, da)
            let tb = _dot(_sub(p, path.at(bi)), db) / _dot(db, db)
            if ta >= -1e-6 and ta < 1 - 1e-6 and tb >= -1e-6 and tb < 1 - 1e-6 {
              let sa = lengths.at(i).at(ai) + ta * _dist(path.at(ai), path.at(ai + 1))
              let sb = lengths.at(i).at(bi) + tb * _dist(path.at(bi), path.at(bi + 1))
              let ta-time = crossing-time(path-times.at(i).at(ai) * (1 - ta) + path-times.at(i).at(ai + 1) * ta)
              let tb-time = crossing-time(path-times.at(i).at(bi) * (1 - tb) + path-times.at(i).at(bi + 1) * tb)
              let total = lengths.at(i).at(lengths.at(i).len() - 1)
              if sa > 1e-5 and sa < total - 1e-5 and sb > 1e-5 and sb < total - 1e-5 {
                let crossing-sine = calc.abs(_cross(da, db)) / (_len(da) * _len(db))
                let self-over = over-at(pair-count, i, i)
                let half-gap = crossing-half-gap(width-at-distance(i,
                  if self-over { sb } else { sa }),
                  crossing-sine: crossing-sine)
                if self-over {
                  events.at(i).push((sb, half-gap))
                  strand-crossings.at(i).push((ta-time,
                    layer-rank(i, crossing-counts.at(i), true)))
                  strand-crossings.at(i).push((tb-time,
                    layer-rank(i, crossing-counts.at(i) + 1, false)))
                } else {
                  events.at(i).push((sa, half-gap))
                  strand-crossings.at(i).push((tb-time,
                    layer-rank(i, crossing-counts.at(i), true)))
                  strand-crossings.at(i).push((ta-time,
                    layer-rank(i, crossing-counts.at(i) + 1, false)))
                }
                crossing-counts.at(i) += 2
                pair-count += 1
              }
            }
          }
        }
      }
    }
  }
  let drawings = ()
  if style == "tube" and occlusion == "mask" {
    // MetaPost splits each strand halfway between successive intersections;
    // each resulting path segment receives the corresponding intLayers rank.
    let strand-segments = range(n).map(_ => ())
    let layer-ranks = ()
    for i in range(n) {
      let sorted = _sort-crossings(strand-crossings.at(i))
      if sorted.len() == 0 {
        strand-segments.at(i).push((path: strands.at(i), rank: 0,
          source-time-range: (path-times.at(i).first(), path-times.at(i).last()),
          radius: widths.at(i)))
        layer-ranks.push(0)
      } else {
        for k in range(sorted.len()) {
          let crossing = sorted.at(k)
          let start = if k == 0 { path-times.at(i).first() }
            else { (sorted.at(k - 1).at(0) + crossing.at(0)) / 2 }
          let finish = if k + 1 == sorted.len() {
            path-times.at(i).last()
          } else { (crossing.at(0) + sorted.at(k + 1).at(0)) / 2 }
          let part = _polyline-time-range(
            strands.at(i), path-times.at(i), start, finish)
          strand-segments.at(i).push((path: part, rank: crossing.at(1),
            source-time-range: (start, finish),
            radius: segment-width(i, (start, finish))))
          layer-ranks.push(crossing.at(1))
        }
      }
    }
    let sorted-ranks = layer-ranks.sorted()
    let shadows-for(rank, current-width) = {
      let shadows = ()
      for i in range(n) {
        for segment in strand-segments.at(i) {
          if segment.rank > rank {
            let shadow = _tube-shadow-plane(segment.path, segment.radius,
              1.5 * current-width, source-cubic-step: source-cubic-step)
            let source-center-units = (segment.source-time-range.at(1)
              - segment.source-time-range.at(0)) * source-cubic-step
            let source-shadow-time-length = 2 * source-center-units + 2
            let edge-index = _polygon-edge-grid(shadow.polygon)
            if _path-intersects-polygon(segment.path, shadow.polygon,
                index: edge-index) {
              shadows.push((polygon: shadow.polygon, depth: shadow.depth,
                edge-index: edge-index,
                source-shadow-time-length: source-shadow-time-length))
            }
          }
        }
      }
      shadows
    }
    let shared-stream = if rng == "metapost" {
      _metapost-rng-sequence(seed, rng-offset + 16384)
    } else { none }
    let rng-cursor = rng-offset
    let cached-drawings = ()
    // The paired source M11 trace visits the last strand first within each
    // rank; preserve that order because it assigns the shared RNG stream.
    // Source layer pictures are evaluated from the highest rank down. Cache
    // their tube renders in that order, while the final compositing below
    // still erases and paints from low rank to high rank.
    if rng == "metapost" {
      let draw-ranks = sorted-ranks.rev()
      for (rank-index, rank) in draw-ranks.enumerate() {
        if rank-index > 0 and rank == draw-ranks.at(rank-index - 1) { continue }
        for i in range(n).rev() {
          for segment-index in range(strand-segments.at(i).len()) {
            let segment = strand-segments.at(i).at(segment-index)
            if segment.rank != rank { continue }
            let current-width = if type(segment.radius) == function {
              (segment.radius)(0.5)
            } else { segment.radius }
            let shadow-planes = shadows-for(rank, current-width)
            let result = tube(segment.path, segment.radius, hatch: "l",
              w: _source-min-stroke, per: 0, seed: seed,
              end-caps: false, rng: "metapost", _random-stream: shared-stream,
              _rng-offset: rng-cursor, _with-rng: true,
              source-cubic-step: source-cubic-step,
              _radial-y-sign: 1,
              _shadow-planes: shadow-planes)
            cached-drawings.push((strand: i, segment: segment-index,
              drawing: result.at(0)))
            rng-cursor = result.at(1)
          }
        }
      }
    }
    for (rank-index, rank) in sorted-ranks.enumerate() {
      if rank-index > 0 and rank == sorted-ranks.at(rank-index - 1) { continue }
      // Mask the accumulated lower layer with every silhouette in this layer
      // before drawing any same-layer hatch, matching source layerPicture.
      for i in range(n).rev() {
        for segment in strand-segments.at(i) {
          if segment.rank != rank { continue }
          if type(segment.radius) == function {
            let silhouette = _tube-shadow-plane(segment.path, segment.radius,
              0, source-cubic-step: source-cubic-step)
            drawings.push(_fill((silhouette.polygon,), white))
          } else {
            drawings.push(stroke-path(segment.path,
              stroke: (paint: white, thickness: 2 * segment.radius * 1mm), per: 0))
          }
        }
      }
      for i in range(n).rev() {
        for (segment-index, segment) in strand-segments.at(i).enumerate() {
          if segment.rank != rank { continue }
          if rng == "metapost" {
            let cached = cached-drawings.filter(item =>
              item.strand == i and item.segment == segment-index).first()
            drawings.push(cached.drawing)
          } else {
            let current-width = if type(segment.radius) == function {
              (segment.radius)(0.5)
            } else { segment.radius }
            drawings.push(tube(segment.path, segment.radius, hatch: "l",
              w: _source-min-stroke, per: 0, seed: seed, end-caps: false,
              source-cubic-step: source-cubic-step,
              _radial-y-sign: 1,
              _shadow-planes: shadows-for(rank, current-width)))
          }
        }
      }
    }
  } else {
    for i in range(n) {
      let fragments = _strand-fragments(strands.at(i), lengths.at(i), events.at(i))
      for fragment in fragments {
        let width = width-over-distance-range(i, fragment.range)
        if style == "tube" {
          drawings.push(tube(fragment.path, width,
            hatch: "l", w: _source-min-stroke, per: 0, seed: seed,
            source-cubic-step: source-cubic-step,
            _radial-y-sign: 1,
            end-caps: false))
        } else {
          drawings.push(stroke-ink(fragment.path, width, closed: false,
            per: 0, fill: stroke, seed: seed))
        }
      }
    }
  }
  _join(drawings)
}
