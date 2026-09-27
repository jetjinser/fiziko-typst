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

// ---------------------------------------------------------------------------
// constants
// ---------------------------------------------------------------------------
#let pt = 0.3514598          // one TeX point in millimetres
#let _mp-unit = 25.4 / 72    // MetaPost's unit scalar is one PostScript bp
#let min-width = 0.3 * pt    // thinnest printable line (mm); below this we dash
#let dash-min-length = 6 * min-width // MetaPost thinBrushPattern minimum (mm)
#let _source-min-stroke = 0.2 * pt
#let _source-max-shading = 1.5 * _source-min-stroke
#let _source-spacing = 3 * _source-max-shading
#let _source-dash-length = 6 * _source-min-stroke

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
#let _normal(a) = {
  let u = _unit(a)
  (-u.at(1), u.at(0))
}
#let _dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
#let _mod(a, b) = calc.rem(calc.rem(a, b) + b, b)
#let _rng(seed, key, salt) = {
  // Park–Miller-style integer mixing. All intermediate products stay below
  // 2^53, so Typst's numeric representation gives stable results.
  let m = 2147483647
  let s0 = _mod(int(seed), m)
  let s1 = _mod(s0 * 48271 + 1, m)
  let s = _mod(s1 * 48271 + 1, m)
  let k = _mod(int(key), m)
  let state = _mod(s + _mod(k * 104729, m) + salt * 13007, m)
  _mod(state * 48271 + 1, m) / m
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
// sampling — Catmull-Rom through the given anchors
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

/// Resample a polyline into a dense, smooth point list.
#let resample(pts, per: 12, closed: false) = {
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

/// Tangent/normal frames along a dense point list.
#let _frame(pts, closed) = {
  pts.enumerate().map(((i, p)) => {
    let d = _sub(_at(pts, i + 1, closed), _at(pts, i - 1, closed))
    let u = _unit(d)
    (p, (-u.at(1), u.at(0)))
  })
}

#let _prepare(pts, per, closed) = if per > 0 { resample(pts, per: per, closed: closed) } else { pts }

// ---------------------------------------------------------------------------
// ink machinery — variable-width bands, ink-conserving dashes
// ---------------------------------------------------------------------------

/// Build closed loops (for filling) from frames + per-point widths.
/// Widths below `minw` are replaced by dashes of width `minw` whose coverage
/// (dash length / period) equals w / minw, keeping ink per unit length.
#let _ink-loops(fr, ws, closed, minw, minlen, seed: 0, dash-extra: 0, dash-cap: 0,
                with-rng: false, with-stats: false) = {
  let n = fr.len()
  let step = (minw - minw / 3) / 16
  let dash-floor = minw / 3 + dash-extra
  let loops = ()
  let rng-cursor = 0
  let thin-leaf-count = 0
  let outer-leaf-count = 0
  let adj = range(n).map(i => {
    let j = if closed { _mod(i + 1, n) } else { calc.clamp(i + 1, 0, n - 1) }
    _dist(fr.at(i).at(0), fr.at(j).at(0))
  })

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
    let base = calc.floor(s)
    let t = s - base
    let i = if closed { _mod(base, n) } else { calc.clamp(base, 0, n - 1) }
    let j = if closed { _mod(base + 1, n) } else { calc.clamp(base + 1, 0, n - 1) }
    ws.at(i) * (1 - t) + ws.at(j) * t
  }
  let split-path(path, target) = {
    let total = 0.0
    for q in range(path.len() - 1) {
      total += _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
    }
    let best-distance = 1e99
    let crossing = none
    let arc = 0.0
    for q in range(path.len() - 1) {
      let a = width-index(path.at(q))
      let b = width-index(path.at(q + 1))
      let span = _dist(frame-index(path.at(q)).at(0), frame-index(path.at(q + 1)).at(0))
      if a != b and ((a <= target and b >= target) or (a >= target and b <= target)) {
        let f = calc.clamp((target - a) / (b - a), 0.0, 1.0)
        let at = arc + f * span
        let distance = calc.abs(at - total / 2)
        if distance < best-distance {
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
      let cut = path.at(q) + (path.at(q + 1) - path.at(q)) * f
      if at <= 0.01 or total - at <= 0.01 { none } else {
        let left = path.slice(0, q + 1) + (cut,)
        let right = (cut,) + path.slice(q + 1)
        let llen = range(left.len() - 1).map(i => _dist(frame-index(left.at(i)).at(0), frame-index(left.at(i + 1)).at(0))).sum()
        let rlen = range(right.len() - 1).map(i => _dist(frame-index(right.at(i)).at(0), frame-index(right.at(i + 1)).at(0))).sum()
        (left, right, llen, rlen, at, total)
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
    let jitter = _rng(seed, key, 1)
    let dash0 = minlen * (1 + calc.pow(c, 2.5)) * (1 + 0.5 * jitter) / 2
    let gap0 = (minw - qw) * dash0 / qw
    let count = calc.max(1, calc.round(total / (dash0 + gap0)))
    let period = total / count
    let dash = period * c
    let gap = period - dash
    // Seeded, stable half-period choice. The same seed preserves this pattern;
    // a different seed changes it without introducing mutable global state.
    let centered-on = _rng(seed, key, 2) < 0.5

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
        let cap = if dash-cap == 1 { minw / 2 } else { 0.0 }
        for (idx, e) in frames.enumerate() {
          let tangent = (e.at(1).at(1), -e.at(1).at(0))
          let along = if idx == 0 { -cap } else if idx == frames.len() - 1 { cap } else { 0.0 }
          let p = _add(e.at(0), _mul(tangent, along))
          fwd.push(_add(p, _mul(e.at(1), minw / 2)))
          bwd.push(_sub(p, _mul(e.at(1), minw / 2)))
        }
        fwd + bwd.rev()
      }
    }

    if centered-on {
      for k in range(int(count) + 1) {
        let center = k * period
        let lp = draw-dash(calc.max(0.0, center - dash / 2), calc.min(total, center + dash / 2))
        if lp != none { out.push(lp) }
      }
    } else {
      for k in range(int(count)) {
        let start = gap / 2 + k * period
        let lp = draw-dash(start, calc.min(total, start + dash))
        if lp != none { out.push(lp) }
      }
    }
    (out, 2)
  }

  // Split thin runs at a width crossing. Each leaf is one nearly
  // constant-width dashed path.
  let refine-thin(pos) = {
    let pending = ((pos, 0),)
    let leaves = ()
    while pending.len() > 0 {
      let node = pending.pop()
      let path = node.at(0)
      let depth = node.at(1)
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
      let base = minw / 3
      let target = if lo > base - 0.01 * _mp-unit {
        base + calc.floor(((hi + lo) / 2 - base) / step) * step
      } else { base }
      let candidate = split-path(path, target)
      let split = if candidate != none and (candidate.at(2) > minlen or candidate.at(3) > minlen) {
        (candidate.at(0), candidate.at(1))
      } else { none }
      if hi - lo >= step and depth < 15 and split != none {
        pending.push((split.at(1), depth + 1))
        pending.push((split.at(0), depth + 1))
      } else if hi > dash-floor {
        leaves.push((path, calc.min(minw, target)))
      }
    }
    leaves
  }

  // Reproduce brushGenerate's outer recursion: split the whole path at each
  // minStrokeWidth crossing, choosing cutPathTime's midpoint-nearest crossing.
  let initial-path = if closed { range(n + 1).map(i => float(i)) } else { range(n).map(i => float(i)) }
  let pending = ((initial-path, 0),)
  let leaves = ()
  while pending.len() > 0 {
    let node = pending.pop()
    let path = node.at(0)
    let depth = node.at(1)
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
    let crossing = split-path(path, minw)
    if hi > minw and lo < minw and depth < 10 and total > minlen and crossing != none {
      pending.push((crossing.at(1), depth + 1))
      pending.push((crossing.at(0), depth + 1))
    } else if lo > 0.99 * minw {
      leaves.push((path, 2))
    } else if hi < 1.01 * minw {
      leaves.push((path, 1))
    }
  }
  for leaf in leaves {
    let path = leaf.at(0)
    outer-leaf-count += 1
    if leaf.at(1) == 2 {
      loops.push(band(path))
    } else {
      for thin-leaf in refine-thin(path) {
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
    (loops, rng-cursor, (outer: outer-leaf-count, thin: thin-leaf-count, dashes: rng-cursor / 2))
  } else if with-rng { (loops, rng-cursor) } else { loops }
}

#let _fill(loops, paint) = {
  let segs = ()
  for lp in loops {
    if lp == none or lp.len() < 3 { continue }
    segs.push(curve.move(_mm(lp.at(0))))
    for p in lp.slice(1) { segs.push(curve.line(_mm(p))) }
    segs.push(curve.line(_mm(lp.at(0))))
  }
  if segs.len() == 0 { none } else { curve(fill: paint, stroke: none, ..segs) }
}

// Sample a path by arc length so stipple density does not depend on its
// polygon resolution. `w / dot-size` controls the chance of placing a dot.
#let _dot-loop(p, diameter) = {
  let r = diameter / 2
  range(6).map(q => {
    let angle = (q * 60 + 30) * 1deg
    _add(p, (r * calc.cos(angle), r * calc.sin(angle)))
  })
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
#let _shadowed(p, regions, center, depth: 0,
               light: (-0.353553, 0.382683, 0.853553), shadow-planes: ()) = {
  let local = _sub(p, center)
  let explicit = regions.any(poly => _inside-poly(local, poly))
  let projected = shadow-planes.any(shadow => {
    let dz = shadow.depth - depth
    // A plane occludes a surface point only when it lies toward the light.
    // Shadow polygon coordinates use world XY (y up); drawing points use
    // screen XY (y down).
    if calc.abs(light.at(2)) < 0.000001 or dz * light.at(2) <= 0 { false }
    else {
      let t = dz / light.at(2)
      _inside-poly((local.at(0) + light.at(0) * t,
                    -local.at(1) + light.at(1) * t), shadow.polygon)
    }
  })
  explicit or projected
}

/// A planar occluder for automatic sphere-shadow projection. `polygon` uses
/// sphere-local XY coordinates with y up; `depth` is positive toward the
/// viewer. `light` uses the same x-right, y-up, z-toward-viewer axes.
#let sphere-shadow-plane(polygon, depth) = (polygon: polygon, depth: depth)
#let _stipple-loops(fr, ws, closed, step, dot-size, seed) = {
  let n = fr.len()
  if n < 2 or step <= 0 or dot-size <= 0 { return () }
  let count = if closed { n } else { n - 1 }
  let cum = (0.0,)
  for i in range(count) {
    cum.push(cum.last() + _dist(fr.at(i).at(0), fr.at(calc.rem(i + 1, n)).at(0)))
  }
  let total = cum.last()
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
      _mul(normal, (2 * _rng(seed, key, 3) - 1) * dot-size * 0.45))
    loops.push(_dot-loop(p, dot-size))
  }
  loops
}

// ---------------------------------------------------------------------------
// public primitives
// ---------------------------------------------------------------------------

/// Offset curve: points at distance f(t) along the normal, t in [0, 1]
/// running along the path (cf. MetaPost's offsetPath(p)(f)).
#let offset-path(pts, f, closed: true, per: 12, shift: (0, 0)) = {
  let src = pts.map(p => _add(p, shift))
  let fr = _frame(_prepare(src, per, closed), closed)
  let n = fr.len()
  fr.enumerate().map(((i, e)) => {
    let t = if closed { i / n } else { i / (n - 1) }
    _add(e.at(0), _mul(e.at(1), _val(f, t)))
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
/// optionally displaced by offset(t). Ink-conserving below `min-w`;
/// `seed` controls deterministic dash-length variation and phase (default 0).
#let stroke-ink(pts, w, offset: 0, closed: true, per: 12,
                min-w: min-width, period: dash-min-length, seed: 0,
                shift: (0, 0), fill: black) = {
  let src = pts.map(p => _add(p, shift))
  let fr0 = _frame(_prepare(src, per, closed), closed)
  let n = fr0.len()
  let fr = fr0.enumerate().map(((i, e)) => {
    let t = if closed { i / n } else { i / (n - 1) }
    (_add(e.at(0), _mul(e.at(1), _val(offset, t))), e.at(1))
  })
  let ws = range(n).map(i => {
    let t = if closed { i / n } else { i / (n - 1) }
    _val(w, t)
  })
  place(top + left, _fill(_ink-loops(fr, ws, closed, min-w, period, seed: seed), fill))
}

/// Deterministic stippled stroke. `w(t)` is the local density in mm;
/// `dot-size` and `step` control individual dots and spacing independently.
#let stroke-stipple(pts, w, offset: 0, closed: true, per: 12,
                    dot-size: _source-max-shading, step: 2.5 * _source-max-shading,
                    seed: 0, shift: (0, 0), fill: black) = {
  let src = pts.map(p => _add(p, shift))
  let fr0 = _frame(_prepare(src, per, closed), closed)
  let n = fr0.len()
  let fr = fr0.enumerate().map(((i, e)) => {
    let t = if closed { i / n } else { i / (n - 1) }
    (_add(e.at(0), _mul(e.at(1), _val(offset, t))), e.at(1))
  })
  let ws = range(n).map(i => _val(w, if closed { i / n } else { i / (n - 1) }))
  place(top + left, _fill(_stipple-loops(fr, ws, closed, step, dot-size, seed), fill))
}

/// Sphere as concentric rings whose thickness follows a Lambert light model.
/// `light` is a 3D direction (x right, y up, z towards the viewer).
#let sphere(d, light: (-0.353553, 0.382683, 0.853553), rings: auto, samples: 300,
            max-w: _source-max-shading, gamma: 1.0,
            min-w: _source-min-stroke, period: _source-dash-length,
            seed: 0, center: (0, 0), shadow-regions: (), shadow-planes: (), fill: black) = {
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
  for k in range(1, ring-count + 1) {
    let r = R * k / ring-count
    let pts = range(samples).map(j => {
      let a = 360 * j / samples
      _add(center, (r * _cos(a), r * _sin(a)))
    })
    let fr = _frame(pts, true)
    let ws = fr.enumerate().map(((i, e)) => {
      let p = e.at(0)
      let z = calc.sqrt(calc.max(0.0, R * R - r * r))
      let nx = (p.at(0) - center.at(0)) / R
      let ny = -(p.at(1) - center.at(1)) / R   // screen y is down
      let nz = z / R
      let lam = calc.max(0.0, nx * L.at(0) + ny * L.at(1) + nz * L.at(2))
      if _shadowed(p, shadow-regions, center, depth: z, light: L,
                   shadow-planes: shadow-planes) { max-w }
      else { max-w * calc.pow(1 - lam, gamma) }
    })
    loops += _ink-loops(fr, ws, true, min-w, period, seed: seed)
  }
  place(top + left, _fill(loops, fill))
}

/// Stippled sphere with a jittered two-dimensional point field and Lambert
/// lighting. Dot spacing controls the field resolution and expected density.
#let sphere-stipple(d, light: (-0.353553, 0.382683, 0.853553),
                    dot-step: 0.18, dot-size: 0.4 * pt,
                    gamma: 1.0, seed: 0,
                    center: (0, 0), shadow-regions: (), shadow-planes: (), fill: black) = {
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
      let lam = calc.max(0.0, nx * L.at(0) + ny * L.at(1) + nz * L.at(2))
      let depth = R * nz
      let dark = if _shadowed(p, shadow-regions, center, depth: depth, light: L,
                              shadow-planes: shadow-planes) { 1.0 }
                 else { calc.pow(1 - lam, gamma) }
      if _rng(seed, key * key + 1, 3) < dark { loops.push(_dot-loop(p, dot-size)) }
    }
  }
  place(top + left, _fill(loops, fill))
}

/// Sphere shaded with the original fiziko-style latitudinal strokes.
/// `latitude` controls the projection of each parallel, while `spacing`
/// determines how many parallels are used for this diameter. The default
/// drawing resolution retains width-template knots while avoiding excessive
/// intermediate points; increase `samples` for unusually large output.
#let sphere-latitude(d, latitude: -60, light: (-0.353553, 0.382683, 0.853553),
                     max-w: _source-max-shading, spacing: _source-spacing, samples: 180,
                     gamma: 1.0, min-w: _source-min-stroke, period: _source-dash-length,
                     seed: 1, rng-offset: 0, with-rng: false, with-trace: false,
                     center: (0, 0), fill: black) = {
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
    // offsetPathTemplate's x coordinate is arc length, so its piecewise
    // linear width function must be sampled against arc length as well.
    let knot-s = knot-ts.map(t => {
      let q = calc.clamp((t - t-start) / (t-finish - t-start) * samples, 0.0, samples)
      if q >= samples { path-length } else {
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
      max-w * _lat-density(density, k) * calc.pow(1 - lam, gamma)
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
    let knot = 1
    for i in range(count) {
      fr.push(base-fr.at(i))
      widths.push(ws.at(i))
      if i + 1 < path-s.len() {
        let start-s = path-s.at(i)
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
          }
          knot += 1
        }
      }
    }
    let ink = _ink-loops(
      fr, widths, full, min-w, period, seed: seed + rng-offset,
      dash-extra: 0.01 * _mp-unit,
      dash-cap: 1,
      with-rng: true, with-stats: with-trace,
    )
    if with-trace {
      trace.push((latitude: k, path-length: path-length,
        width-min: calc.min(..knot-ws), width-max: calc.max(..knot-ws),
        knot-s: knot-s, knot-w: knot-ws,
        brush-nodes: fr.len(),
        outer-leaves: ink.at(2).outer, thin-leaves: ink.at(2).thin,
        dash-calls: ink.at(2).dashes))
    }
    out += ink.at(0)
    rng-cursor += ink.at(1)
  }
  // Keep the silhouette independent of the latitude hatching.
  let rim = range(samples).map(j => {
    let a = 360 * j / samples
    _add(center, (R * _cos(a), R * _sin(a)))
  })
  let rfr = _frame(rim, true)
  let rws = range(rfr.len()).map(_ => min-w)
  out += _ink-loops(rfr, rws, true, min-w, period, seed: seed)
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
  (p, v, (i + f) / (n - 1))
}

/// Tube geometry as plain data (so verify.typ can assert on it):
///   * `sides-offset`: the outline sits at ± this radius, per t
///   * `inner`: longitudinal lines — position = fraction `u` of the *local*
///     radius, width = local ink budget (coverage × local spacing)
///   * `trans`: transverse lines at arc-length positions, thickness clamped
///     to the printable minimum (spacing grows to keep ink per area)
#let _tube-layout(pts, radius, hatch: "l", spacing: 3 * _source-max-shading, coverage: auto,
                  closed: false, per: 12, w: 0.5 * pt, min-w: min-width,
                  max-w: _source-max-shading,
                  light: (-0.353553, 0.382683, 0.853553), gamma: 1.0,
                  shift: (0, 0)) = {
  let src = pts.map(p => _add(p, shift))
  let fr = _frame(_prepare(src, per, closed), closed)
  let n = fr.len()
  let rfun(t) = calc.max(0.0, _val(radius, t))
  let t-of(i) = if closed { i / n } else { i / (n - 1) }
  let rs = range(n).map(i => rfun(t-of(i)))
  let rmax = calc.max(..rs)
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let L = (light.at(0) / ln, light.at(1) / ln, light.at(2) / ln)
  let normal-at(t) = {
    let x = if closed { t * n } else { t * (n - 1) }
    let i = calc.min(n - 1, int(calc.floor(x)))
    let j = if closed { _mod(i + 1, n) } else { calc.min(n - 1, i + 1) }
    let f = x - i
    _unit((
      fr.at(i).at(1).at(0) * (1 - f) + fr.at(j).at(1).at(0) * f,
      fr.at(i).at(1).at(1) * (1 - f) + fr.at(j).at(1).at(1) * f,
    ))
  }
  let shade(u, t) = {
    let nv = normal-at(t)
    let nz = calc.sqrt(calc.max(0.0, 1 - u * u))
    calc.pow(calc.clamp(1 - u * nv.at(0) * L.at(0) - u * nv.at(1) * L.at(1) - nz * L.at(2), 0.0, 1.0), gamma)
  }
  let cov = if coverage == auto { if hatch == "t" or hatch == "s" { 0.4 } else { 0.15 } } else { coverage }

  let inner-n = calc.max(0, int(calc.round(2 * rmax / spacing)) - 1)
  let inner = range(1, inner-n + 1).map(k => {
    let u = -1.0 + 2.0 * k / (inner-n + 1)
    (
      u: u,
      offset: t => u * rfun(t),
      w: t => calc.min(max-w, calc.max(0.0, cov * 2 * rfun(t) / (inner-n + 1))) * shade(u, t),
    )
  })

  let trans = ()
  if hatch == "t" and n > 1 and not closed {
    let cum = (0.0,)
    let acc = 0.0
    for i in range(n - 1) {
      acc += _dist(fr.at(i).at(0), fr.at(i + 1).at(0))
      cum.push(acc)
    }
    let len = acc
    let wt = calc.max(cov * spacing, min-w)
    let s = wt / cov
    let K = 5
    let j = 0
    while j * s <= len + 1e-9 {
      let pos = calc.min(j * s, len)
      let (p, nv, t) = _frame-at(fr, cum, pos)
      let r = rfun(t)
      let tv = (nv.at(1), -nv.at(0))
      let fwd = range(2 * K + 1).map(jj => {
        let u = -1.0 + 2.0 * jj / (2 * K)
        _add(_add(p, _mul(nv, u * r)), _mul(tv, wt / 2))
      })
      let bwd = range(2 * K + 1).map(jj => {
        let u = -1.0 + 2.0 * jj / (2 * K)
        _add(_add(p, _mul(nv, u * r)), _mul(tv, -wt / 2))
      })
      trans.push((t: t, w: wt, s: s, pos: pos, loop: fwd + bwd.rev()))
      j += 1
    }
  }

  (
    frames: fr,
    rfun: rfun,
    rmax: rmax,
    cov: cov,
    inner-n: inner-n,
    inner: inner,
    trans: trans,
    w: w,
  )
}

/// Tube: two offset outlines plus hatching.
/// `seed` controls any thin-brush dashes used by the outlines and hatches.
///   * `radius` — a number or a function of t (t runs 0..1 along the path);
///     varying radius gives cones, waisted tubes, fisiko's fig. 8 ring, …
///   * `hatch: "l"` — longitudinal lines; count follows the widest section,
///     positions follow the local radius, widths follow the local ink budget
///   * `hatch: "t"` — transverse lines at constant ink per unit area; when
///     the desired thickness falls below `min-w` the spacing grows instead
///   * `hatch: "s"` — stippled longitudinal paths
///   * `hatch: none` — outline only
#let tube(pts, radius, hatch: "l", spacing: 3 * _source-max-shading, coverage: auto, closed: false,
          w: 0.5 * pt, per: 12, min-w: min-width, period: dash-min-length,
          max-w: _source-max-shading, light: (-0.353553, 0.382683, 0.853553),
          gamma: 1.0, seed: 0, shift: (0, 0),
          dot-size: 0.4 * pt, dot-step: 0.18) = {
  let hatch-spacing = if hatch == "s" { calc.min(spacing, 3 * dot-size) } else { spacing }
  let L = _tube-layout(pts, radius, hatch: hatch, spacing: hatch-spacing,
                       coverage: coverage, closed: closed, per: per,
                       w: w, min-w: min-w, max-w: max-w, light: light,
                       gamma: gamma, shift: shift)
  let src = pts.map(p => _add(p, shift))
  let els = (
    stroke-ink(src, w, offset: L.rfun, closed: closed, per: per,
               min-w: min-w, period: period, seed: seed),
    stroke-ink(src, w, offset: t => -(L.rfun)(t), closed: closed, per: per,
               min-w: min-w, period: period, seed: seed),
  )
  // MetaPost closes open tube outlines across both ends. Connect the two
  // offset boundaries here as well; closed centerlines have no end caps.
  if not closed {
    for (i, t) in ((0, 0.0), (L.frames.len() - 1, 1.0)) {
      let frame = L.frames.at(i)
      let rad = (L.rfun)(t)
      if rad > 0.000001 {
        let a = _add(frame.at(0), _mul(frame.at(1), rad))
        let b = _add(frame.at(0), _mul(frame.at(1), -rad))
        els.push(stroke-path((a, b), stroke: w * 1mm + black, closed: false, per: 0))
      }
    }
  }
  if hatch == "l" {
    els += L.inner.map(it => stroke-ink(src, it.w, offset: it.offset,
      closed: closed, per: per, min-w: min-w, period: period, seed: seed))
  } else if hatch == "s" {
    els += L.inner.enumerate().map(((i, it)) => stroke-stipple(src,
      t => dot-size * calc.clamp((it.w)(t) / max-w, 0.0, 1.0),
      offset: it.offset, closed: closed, per: per,
      dot-size: dot-size, step: dot-step, seed: seed + i * 7919))
  }
  if L.trans.len() > 0 {
    els.push(place(top + left, _fill(L.trans.map(tr => tr.loop), black)))
  }
  _join(els)
}

// Intersect evenly spaced scanlines with a closed polygon. Each line returns
// one or more inside intervals, including concave polygons and disjoint cuts.
#let _scanline-segments(poly, angle, spacing) = {
  if poly.len() < 3 or spacing <= 0 { return () }
  let d = (_cos(angle), _sin(angle))
  let n = (-d.at(1), d.at(0))
  let projections = poly.map(p => _dot(p, n))
  let lo = calc.min(..projections)
  let hi = calc.max(..projections)
  let count = calc.max(1, int(calc.ceil((hi - lo) / spacing)))
  let segments = ()
  for row in range(count + 1) {
    let offset = lo + row * spacing
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

/// Parallel clipped strokes inside a polygon. `style: "glass"` leaves
/// periodic gaps to suggest a transparent material.
#let solid(poly, angle: 45, style: "opaque", spacing: 0.65, stroke: 0.35pt + black) = {
  let segs = _scanline-segments(poly, angle, spacing)
  let items = ()
  for s in segs {
    let row = s.at(2)
    if style == "glass" and calc.rem(row, 3) == 1 { continue }
    items.push(stroke-path((s.at(0), s.at(1)), stroke: stroke, closed: false, per: 0))
  }
  _join(items)
}

/// A clipped set of strokes whose width increases across the polygon.
#let gradient-shade(poly, angle: 90, spacing: 0.4,
                    min-w: 0.15 * pt, max-w: 0.45 * pt, seed: 0) = {
  let segs = _scanline-segments(poly, angle, spacing)
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
#let flat-surface(poly, normal, angle: 30, style: "hatch", spacing: 0.65,
                  dot-size: 0.3 * pt, dot-step: 0.65, seed: 0,
                  light: (-0.353553, 0.382683, 0.853553)) = {
  let nn = calc.sqrt(normal.at(0) * normal.at(0) + normal.at(1) * normal.at(1) + normal.at(2) * normal.at(2))
  let ln = calc.sqrt(light.at(0) * light.at(0) + light.at(1) * light.at(1) + light.at(2) * light.at(2))
  let lam = calc.max(0.0, (normal.at(0) * light.at(0) + normal.at(1) * light.at(1) + normal.at(2) * light.at(2)) / (nn * ln))
  let shade = calc.pow(1 - lam, 1.0)
  let segs = _scanline-segments(poly, angle, spacing)
  let items = ()
  for s in segs {
    let edge-fade = calc.sin(180deg * s.at(2) / calc.max(1, s.at(3)))
    let density = shade * (0.15 + 0.85 * edge-fade)
    if style == "stipples" {
      items.push(stroke-stipple((s.at(0), s.at(1)), dot-size * density,
        closed: false, per: 0, dot-size: dot-size, step: dot-step,
        seed: seed + s.at(2)))
    } else {
      items.push(stroke-ink((s.at(0), s.at(1)), _source-max-shading * density,
        closed: false, per: 0, seed: seed + s.at(2)))
    }
  }
  _join(items)
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
  let inset = offset-path(path, -thickness, closed: false)
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

/// Pulley wheel: white disc (hides the rope kink beneath), rim, groove,
/// axle dot. Drawn after the ropes, as in fisiko's masked figure.
#let pulley(d, center: (0, 0), groove: 5 / 6) = {
  let R = d / 2
  _join((
    place(top + left, _fill((circle-pts(R + 0.6, 96, center: center),), white)),
    stroke-path(circle-pts(R, 96, center: center),
                stroke: 0.6pt + black, closed: true, per: 0),
    stroke-path(circle-pts(R * groove, 96, center: center),
                stroke: 0.45pt + black, closed: true, per: 0),
    place(top + left, _fill((circle-pts(d / 16, 24, center: center),), black)),
  ))
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
  let n = if rings == auto { calc.max(2, int(calc.round(d / 1.6))) } else { rings }
  _join((
    place(top + left, _fill((circle-pts(d / 2, 96, center: center),), white)),
    sphere(d * 0.98, center: center, rings: n, seed: seed),
    stroke-path(circle-pts(d * 8 / 9 / 2, 96, center: center), stroke: 0.45pt + black, closed: true, per: 0),
    stroke-path(circle-pts(d * 7 / 9 / 2, 96, center: center), stroke: 0.35pt + black, closed: true, per: 0),
    stroke-path(circle-pts(d * 3 / 5 / 2, 96, center: center), stroke: 0.35pt + black, closed: true, per: 0),
    stroke-path(circle-pts(d / 16, 24, center: center), stroke: 0.5pt + black, closed: true, per: 0),
  ))
}

/// A wheel with a rim, hub, and evenly spaced spokes.
#let wheel(d, center: (0, 0), spokes: 6, rim: 0.82, stroke: 0.55pt + black) = {
  let R = d / 2
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

/// The full L'Hôpital pulley figure: beam, ropes, wheel, weight, labels.
/// `AB`, `l`, `m` in units (fisiko used cm); `k` millimetres per unit.
/// Wood-grain on the beam arrives with the grain milestone — for now the
/// beam is hatched as in figure 5.
#let l-hopital-pulley(AB, l, m, at: (0, 0), k: 6, d1: 2 / 3, d2: 1,
                      rope-w: 0.6, seed: 0) = {
  let G = _pulley-geometry(AB, l, m, d1: d1)
  let to-mm(p) = _add(_mul(p, k), at)
  let A = to-mm(G.A)
  let B = to-mm(G.B)
  let C = to-mm(G.C)
  let D = to-mm(G.D)
  let E = to-mm(G.E)
  let y0 = at.at(1)
  let els = ()

  // support beam (hatched; wood grain comes later)
  let bw = 4.0
  els.push(stroke-ink(((A.at(0) - bw, y0), (B.at(0) + bw, y0)),
                      0.9, closed: false, per: 6, seed: seed))
  let span = (B.at(0) + bw) - (A.at(0) - bw)
  let nh = calc.max(3, int(calc.round(span / 4.5)))
  els += range(nh).map(i => {
    let x = A.at(0) - bw + span * (i + 0.5) / nh
    stroke-path(((x, y0), (x - 1.7, y0 - 2.6)),
                stroke: 0.4pt + black, per: 2)
  })

  // ropes
  els.push(stroke-ink((A, D), rope-w, closed: false, per: 6, seed: seed))
  els.push(stroke-ink((B, D), rope-w, closed: false, per: 6, seed: seed))
  els.push(stroke-ink((D, C), rope-w, closed: false, per: 6, seed: seed))

  // wheel over the kink, then the weight
  els.push(pulley(d1 * k, center: E))
  els.push(sphere(d2 * k, seed: seed, center: (C.at(0), C.at(1) + d2 * k / 2)))

  // dots and labels
  let dot(p) = place(top + left, _fill((circle-pts(0.35, 20, center: p),), black))
  els.push(dot(A) + dot(B))
  els.push(tag($A$, (A.at(0) - 2.4, A.at(1) + 3.4)))
  els.push(tag($B$, (B.at(0) + 2.4, B.at(1) + 3.4)))
  els.push(tag($C$, (C.at(0) - 3.2, C.at(1) - 1.2)))
  let mid(p, q) = ((p.at(0) + q.at(0)) / 2, (p.at(1) + q.at(1)) / 2)
  let uAD = _unit(_sub(D, A))
  let uBD = _unit(_sub(D, B))
  els.push(tag($l$, _add(mid(A, D), _mul((uAD.at(1), -uAD.at(0)), 2.6))))
  els.push(tag($m$, _add(mid(B, D), _mul((-uBD.at(1), uBD.at(0)), 2.6))))
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

#let _stroke-segments(segments, stroke) = {
  let segs = ()
  for s in segments {
    segs.push(curve.move(_mm(s.at(0))))
    segs.push(curve.line(_mm(s.at(1))))
  }
  if segs.len() == 0 { none }
  else { place(top + left, curve(fill: none, stroke: stroke, ..segs)) }
}

/// Wood-grain contours clipped to an arbitrary simple polygon. `eyes` use
/// coordinates local to the polygon's bounding box.
#let wooden-thing(poly, angle: 0, spacing: 2.6, eyes: (), cell: 1.0,
                  stroke: 0.45pt + black) = {
  if poly.len() < 3 { return none }
  let xs = poly.map(p => p.at(0))
  let ys = poly.map(p => p.at(1))
  let x0 = calc.min(..xs)
  let y0 = calc.min(..ys)
  let w = calc.max(..xs) - x0
  let h = calc.max(..ys) - y0
  if w <= 0 or h <= 0 { return none }
  let local-poly = poly.map(p => _sub(p, (x0, y0)))
  let nx = calc.max(8, int(calc.ceil(w / cell)))
  let ny = calc.max(8, int(calc.ceil(h / cell)))
  let field = _wood-field(angle, spacing, eyes)
  let contours = marching-squares(field, 0, 0, w, h, step: 1, nx: nx, ny: ny)
  let segments = ()
  for contour in contours {
    let clipped = _clip-polyline(contour, (local-poly,))
    segments += clipped.map(seg => (
      _add(seg.at(0), (x0, y0)), _add(seg.at(1), (x0, y0)),
    ))
  }
  let eye-loops = eyes.filter(e => _inside-poly((e.at(0), e.at(1)), local-poly)).map(e =>
    _ellipse-pts(e.at(2) * 0.6, e.at(2) * 0.38, rot: angle,
                 center: _add((e.at(0), e.at(1)), (x0, y0)))
  )
  let els = (_stroke-segments(segments, stroke),
             stroke-path(poly, stroke: stroke, closed: true, per: 0))
  if eye-loops.len() > 0 { els.push(place(top + left, _fill(eye-loops, black))) }
  _join(els)
}

/// A plank of wood: iso-lines of the year-ring field, clipped to the
/// rectangle (x, y, w, h), with a dark eye at each knot.
///   * `angle` — grain direction in degrees (0 = horizontal)
///   * `spacing` — distance between rings (mm)
///   * `eyes` — ((x, y, size, amp), ...) in rectangle-local coordinates
#let wood(x, y, w, h, angle: 0, spacing: 2.6, eyes: (),
          stroke: 0.45pt + black, cell: 1.5) = {
  let nx = calc.max(8, int(calc.round(w / cell)))
  let ny = calc.max(8, int(calc.round(h / cell)))
  let f = _wood-field(angle, spacing, eyes)
  let loops = marching-squares(f, 0, 0, w, h, step: 1, nx: nx, ny: ny)
  let rect = ((0, 0), (w, 0), (w, h), (0, h))
  let segments = loops.fold((), (acc, pl) => acc + _clip-polyline(pl, (rect,)))
  let els = (_stroke-segments(segments, stroke),)
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
#let wooden-surface(path, thickness: 2.5, angle: 0, spacing: 0.7,
                    eyes: (), cell: 1.0, stroke: 0.45pt + black) = {
  let outer = resample(path, per: 12, closed: false)
  let inset = offset-path(path, -thickness, closed: false)
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
#let _lens-outline(ap, sag, rim, per: 8) = {
  let h = ap / 2
  let left = resample(((-rim, h), (-sag, 0), (-rim, -h)), per: per, closed: false)
  let right = resample(((rim, h), (sag, 0), (rim, -h)), per: per, closed: false)
  if rim > 0 {
    left + ((-rim, -h),) + right.rev() + ((rim, h),)
  } else {
    left + right.rev()
  }
}

/// Lens at `at`: outline plus optional dashed optical axis (half-length
/// `axis`).
#let lens(ap, sag, rim: 0.0, axis: 0, at: (0, 0), stroke: 0.5pt + black, per: 8) = {
  let out = _lens-outline(ap, sag, rim, per: per).map(p => _add(p, at))
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
#let weight(h, r: 3, neck: 0.45, spacing: 1.4, w: 0.45 * pt,
            at: (0, 0), seed: 0) = {
  let shoulder = 0.3
  let radius(t) = if t < shoulder {
    let u = calc.clamp(t / shoulder, 0.0, 1.0)
    r * (neck + (1 - neck) * u * u * (3 - 2 * u))
  } else { r }
  tube((_add(at, (0, 0)), _add(at, (0, h))), radius,
    spacing: spacing, w: w, per: 12, seed: seed)
}

/// A standing weight: broad body above a tapered lower neck, centred at `at`.
#let weight-standing(h, r: 3, taper: 0.55, body-fraction: 0.68,
                     spacing: 1.4, w: 0.45 * pt,
                     at: (0, 0), seed: 0) = {
  let radius(t) = {
    let u = calc.clamp((t - body-fraction) / (1 - body-fraction), 0.0, 1.0)
    r * (1 - (1 - taper) * u * u * (3 - 2 * u))
  }
  let axis = (_add(at, (0, 0)), _add(at, (0, h)))
  tube(axis, radius, hatch: "l", spacing: spacing, w: w, per: 12, seed: seed)
}

// ---------------------------------------------------------------------------
// geometric optics
// ---------------------------------------------------------------------------

#let _cross(a, b) = a.at(0) * b.at(1) - a.at(1) * b.at(0)

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
  let y = _sin(lat) * _cos(lat0) - _cos(lat) * _cos(u) * _sin(lat0)
  let depth = _sin(lat) * _sin(lat0) + _cos(lat) * _cos(lat0) * _cos(u)
  // Suppress round-off at the exact horizon, so a point on the rim is not
  // alternately classified as visible by tiny trigonometric residuals.
  (x: x, y: y, visible: depth > 1e-10)
}

#let _globe-crossing(a, b, rotation) = {
  let lo = 0.0
  let hi = 1.0
  let av = (globe-project(a.at(0), a.at(1), rotation: rotation)).visible
  for _ in range(14) {
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

#let _globe-visible-paths(coords, rotation, radius, center) = {
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
      let h = _globe-crossing(a, b, rotation)
      let ph = globe-project(h.at(0), h.at(1), rotation: rotation)
      run.push(_add(center, (radius * ph.x, -radius * ph.y)))
      if run.len() > 1 { paths.push(run) }
      run = ()
    } else if not pa.visible and pb.visible {
      let h = _globe-crossing(a, b, rotation)
      let ph = globe-project(h.at(0), h.at(1), rotation: rotation)
      run = (_add(center, (radius * ph.x, -radius * ph.y)),
             _add(center, (radius * pb.x, -radius * pb.y)))
    }
  }
  if run.len() > 1 { paths.push(run) }
  paths
}

/// Orthographic globe with visible latitude/longitude graticules and optional
/// coast polylines. `lands` is a tuple of polylines, each containing (lon,lat)
/// vertices; hidden portions are clipped at the horizon.
#let globe(d, rotation: (0, 0), lands: (), parallels: 30, meridians: 30,
          center: (0, 0), stroke: 0.4pt + black, outline: 0.6pt + black) = {
  let radius = d / 2
  let lines = ()
  if parallels > 0 {
    for k in range(calc.max(0, int(calc.ceil(180 / parallels)) - 1)) {
      let lat = -90 + (k + 1) * parallels
      let geo = range(73).map(i => (-180 + i * 5, lat))
      lines += _globe-visible-paths(geo, rotation, radius, center)
    }
  }
  if meridians > 0 {
    for k in range(int(calc.ceil(360 / meridians))) {
      let lon = k * meridians
      let geo = range(37).map(i => (lon, -90 + i * 5))
      lines += _globe-visible-paths(geo, rotation, radius, center)
    }
  }
  for land in lands {
    lines += _globe-visible-paths(land, rotation, radius, center)
  }
  let elements = lines.map(path => stroke-path(path, stroke: stroke, per: 0))
  elements.push(stroke-path(circle-pts(radius, 180, center: center),
                            stroke: outline, closed: true, per: 0))
  _join(elements)
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
      if part.len() > 1 { result.push(part) }
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
    if part.len() > 1 { result.push(part) }
  }
  result
}

/// Draw sampled strands with real over/under gaps at their intersections.
/// `strands` is a tuple of open polylines. By default, crossings between each
/// strand pair alternate over/under in traversal order. Pass numeric `layers`
/// to keep a fixed global ordering. `widths` may be one width for all strands
/// or a tuple with one width per strand.
#let strand-knot(strands, widths: 1.25, layers: auto, gap: 0.6,
                 self-crossings: true, seed: 0, stroke: black) = {
  let n = strands.len()
  let lengths = strands.map(_polyline-lengths)
  let widths = if type(widths) == array { widths } else { range(n).map(_ => widths) }
  let events = range(n).map(_ => ())
  for i in range(n) {
    for j in range(i + 1, n) {
      let pair-count = 0
      let a = strands.at(i)
      let b = strands.at(j)
      for ai in range(a.len() - 1) {
        let da = _sub(a.at(ai + 1), a.at(ai))
        for bi in range(b.len() - 1) {
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
              let enda = lengths.at(i).at(lengths.at(i).len() - 1)
              let endb = lengths.at(j).at(lengths.at(j).len() - 1)
              if sa <= 1e-5 or sa >= enda - 1e-5 or sb <= 1e-5 or sb >= endb - 1e-5 {
                continue
              }
              let i-over = if layers == auto { _mod(pair-count, 2) == 0 }
                           else { layers.at(i) >= layers.at(j) }
              let half-gap = (widths.at(i) + widths.at(j) + gap) / 2
              if i-over {
                events.at(j).push((sb, half-gap))
              } else {
                events.at(i).push((sa, half-gap))
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
        let da = _sub(path.at(ai + 1), path.at(ai))
        for bi in range(ai + 2, path.len() - 1) {
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
              let total = lengths.at(i).at(lengths.at(i).len() - 1)
              if sa > 1e-5 and sa < total - 1e-5 and sb > 1e-5 and sb < total - 1e-5 {
                let half-gap = widths.at(i) + gap / 2
                if _mod(pair-count, 2) == 0 {
                  events.at(i).push((sb, half-gap))
                } else {
                  events.at(i).push((sa, half-gap))
                }
                pair-count += 1
              }
            }
          }
        }
      }
    }
  }
  let drawings = ()
  for i in range(n) {
    let fragments = _strand-fragments(strands.at(i), lengths.at(i), events.at(i))
    drawings += fragments.map(part => stroke-ink(part, widths.at(i), closed: false,
      per: 0, fill: stroke, seed: seed))
  }
  _join(drawings)
}
