// contour.typ — marching squares with exact chain stitching, for fiziko.typ.
//
// Given a scalar field f over a rectangle, produce the iso-lines as polylines.
// Segments are identified by the *grid edges* they cross (each segment has
// exactly one horizontal and one vertical edge), so chaining is a graph walk
// with integer keys — no floating-point endpoint matching.

// Iterative port of Fiziko's cLine for unmasked grids. Source grid cell (i,j)
// maps to local Typst coordinates (x0+j*dx, y0+h-i*dy). The two directed
// branches are evaluated with loops so long contours do not consume Typst call
// depth.
#let _source-c-line(f, x0, y0, w, h, nx, ny, level) = {
  let visited = (:)
  let dx = w / nx
  let dy = h / ny
  let sign(v) = if v > 0 { 1 } else if v < 0 { -1 } else { 0 }
  let join(a, b) = {
    if a.len() == 0 { b } else if b.len() == 0 { a } else {
      let p = a.last()
      let q = b.first()
      let d = calc.sqrt((p.at(0) - q.at(0)) * (p.at(0) - q.at(0))
        + (p.at(1) - q.at(1)) * (p.at(1) - q.at(1)))
      a + if d < 1e-7 { b.slice(1) } else { b }
    }
  }
  let hits(i, j) = {
    let x = x0 + j * dx
    let y = y0 + h - i * dy
    let c = (f(x, y), f(x + dx, y), f(x, y - dy), f(x + dx, y - dy))
    let edges = (
      (c.at(0), c.at(1), (x, y), (x + dx, y), (-1, 0)),
      (c.at(0), c.at(2), (x, y), (x, y - dy), (0, -1)),
      (c.at(1), c.at(3), (x + dx, y), (x + dx, y - dy), (0, 1)),
      (c.at(2), c.at(3), (x, y - dy), (x + dx, y - dy), (1, 0)),
    )
    let out = ()
    for e in edges {
      let a = e.at(0) - level
      let b = e.at(1) - level
      if sign(a) != sign(b) {
        let t = calc.abs(-a / (b - a))
        let p = e.at(2)
        let q = e.at(3)
        out.push(((p.at(0) + t * (q.at(0) - p.at(0)),
          p.at(1) + t * (q.at(1) - p.at(1))), e.at(4)))
      }
    }
    out
  }
  let branch(i, j, state, seen) = {
    let ci = i
    let cj = j
    let points = ()
    let endpoint = (x0 + cj * dx, y0 + h - ci * dy)
    let done = false
    while not done {
      let key = str(ci) + "," + str(cj)
      if ci < 0 or ci >= ny or cj < 0 or cj >= nx {
        seen.insert(key, true)
        endpoint = (x0 + cj * dx, y0 + h - ci * dy)
        done = true
      } else {
        let ps = hits(ci, cj)
        if ps.len() < 2 {
          endpoint = (x0 + cj * dx, y0 + h - ci * dy)
          done = true
        } else {
          let p1 = ps.at(0).at(0)
          let p2 = ps.at(1).at(0)
          let d1 = ps.at(0).at(1)
          let d2 = ps.at(1).at(1)
          if seen.at(key, default: false) {
            endpoint = ((p1.at(0) + p2.at(0)) / 2,
              (p1.at(1) + p2.at(1)) / 2)
            done = true
          } else {
            seen.insert(key, true)
            let k1 = str(ci + d1.at(0)) + "," + str(cj + d1.at(1))
            let k2 = str(ci + d2.at(0)) + "," + str(cj + d2.at(1))
            let next = if not seen.at(k1, default: false) {
              (d1, p1)
            } else if not seen.at(k2, default: false) {
              (d2, p2)
            } else { ((0, 0), none) }
            if next.at(1) == none {
              endpoint = ((p1.at(0) + p2.at(0)) / 2,
                (p1.at(1) + p2.at(1)) / 2)
              done = true
            } else {
              points.push(next.at(1))
              ci += next.at(0).at(0)
              cj += next.at(0).at(1)
            }
          }
        }
      }
    }
    let path = if state > 0 { (endpoint,) + points.rev() }
      else { points + (endpoint,) }
    (path, seen)
  }
  let paths = ()
  for i in range(ny) {
    for j in range(nx) {
      let key = str(i) + "," + str(j)
      if not visited.at(key, default: false) {
        let ps = hits(i, j)
        if ps.len() >= 2 {
          visited.insert(key, true)
          let p1 = ps.at(0).at(0)
          let p2 = ps.at(1).at(0)
          let d1 = ps.at(0).at(1)
          let d2 = ps.at(1).at(1)
          let first = branch(i + d2.at(0), j + d2.at(1), 1, visited)
          let second = branch(i + d1.at(0), j + d1.at(1), -1, first.at(1))
          visited = second.at(1)
          let path = join(join(first.at(0), (p1, p2)), second.at(0))
          if path.len() >= 2 { paths.push(path) }
        }
      }
    }
  }
  paths
}

/// Iso-lines of `f` over the rectangle (x0, y0, w, h).
/// By default, levels are multiples of `step` spanning the sampled range;
/// `levels` may instead provide an explicit array of scalar values.
/// `level-jitter(index, level)` can offset each successive threshold, and
/// `with-count` also returns the number of thresholds visited. The result is
/// an array of polylines, each an array of (x, y) float points. `source-walk`
/// selects the unmasked, source-grid cLine traversal instead of edge stitching.
#let marching-squares(f, x0, y0, w, h, step: 1.0, nx: 40, ny: 24,
                      levels: none, level-jitter: none, mask: none,
                      with-count: false, source-walk: false) = {
  let dx = w / nx
  let dy = h / ny
  let V = range(ny + 1).map(j => range(nx + 1).map(i => f(x0 + i * dx, y0 + j * dy)))
  let flat = ()
  for row in V { flat += row }
  let l0 = calc.ceil(calc.min(..flat) / step - 1e-9)
  let l1 = calc.floor(calc.max(..flat) / step + 1e-9)
  let level-values = if levels == none {
    range(calc.max(0, l1 - l0 + 1)).map(i => (l0 + i) * step)
  } else { levels }
  let hCount = nx * (ny + 1)

  // case table: index → list of edge pairs ("T"/"R"/"B"/"L"); 5 and 10 (the
  // saddles) are resolved from the cell average, as usual.
  let cases = (
    (),
    (("T", "L"),), (("T", "R"),), (("L", "R"),), (("R", "B"),),
    none,
    (("T", "B"),), (("L", "B"),), (("B", "L"),), (("T", "B"),),
    none,
    (("R", "B"),), (("L", "R"),), (("T", "R"),), (("T", "L"),),
    (),
  )

  let polylines = ()
  let level-count = level-values.len()
  if level-count > 0 {
    for li in range(level-count) {
      let level = level-values.at(li)
      let L = level + if level-jitter == none { 0.0 } else { level-jitter(li, level) }
      if source-walk {
        assert(mask == none,
          message: "source-walk currently requires an unmasked grid")
        polylines += _source-c-line(f, x0, y0, w, h, nx, ny, L)
        continue
      }
      let segs = ()   // (edgeA, pointA, edgeB, pointB)

      for j in range(ny) {
        for i in range(nx) {
          let v0 = V.at(j).at(i)
          let v1 = V.at(j).at(i + 1)
          let v2 = V.at(j + 1).at(i + 1)
          let v3 = V.at(j + 1).at(i)
          let lo = calc.min(v0, v1, v2, v3)
          let hi = calc.max(v0, v1, v2, v3)
          if L < lo or L > hi { continue }
          let b0 = if v0 > L { 1 } else { 0 }
          let b1 = if v1 > L { 2 } else { 0 }
          let b2 = if v2 > L { 4 } else { 0 }
          let b3 = if v3 > L { 8 } else { 0 }
          let idx = b0 + b1 + b2 + b3
          if idx == 0 or idx == 15 { continue }

          let px = x0 + i * dx
          let py = y0 + j * dy
          // Masks address grid cells by their physical center. This gives
          // callers a stable analogue of cLine's per-cell isoLinesMask.
          if mask != none and not mask(px + dx / 2, py + dy / 2) { continue }
          let eT = j * nx + i
          let eB = (j + 1) * nx + i
          let eL = hCount + j * (nx + 1) + i
          let eR = hCount + j * (nx + 1) + (i + 1)
          let t(a, b) = if calc.abs(b - a) < 1e-12 { 0.5 } else {
            calc.min(1.0, calc.max(0.0, (L - a) / (b - a)))
          }
          let pT = (px + dx * t(v0, v1), py)
          let pR = (px + dx, py + dy * t(v1, v2))
          let pB = (px + dx * t(v3, v2), py + dy)
          let pL = (px, py + dy * t(v0, v3))
          let ep(name) = if name == "T" { (eT, pT) } else if name == "R" {
            (eR, pR)
          } else if name == "B" { (eB, pB) } else { (eL, pL) }

          let pairs = if idx == 5 {
            if (v0 + v1 + v2 + v3) / 4 > L { (("T", "R"), ("L", "B")) } else { (("T", "L"), ("R", "B")) }
          } else if idx == 10 {
            if (v0 + v1 + v2 + v3) / 4 > L { (("T", "L"), ("R", "B")) } else { (("T", "R"), ("L", "B")) }
          } else { cases.at(idx) }

          for pr in pairs {
            let (ea, pa) = ep(pr.at(0))
            let (eb, pb) = ep(pr.at(1))
            segs.push((ea, pa, eb, pb))
          }
        }
      }

      // stitch this level's segments into polylines via edge adjacency
      let adj = (:)
      for s in range(segs.len()) {
        for key in (str(segs.at(s).at(0)), str(segs.at(s).at(2))) {
          adj.insert(key, adj.at(key, default: ()) + (s,))
        }
      }
      let used = range(segs.len()).map(_ => false)
      for s0 in range(segs.len()) {
        if used.at(s0) { continue }
        used.at(s0) = true
        let eA0 = segs.at(s0).at(0)
        let pA0 = segs.at(s0).at(1)
        let eB0 = segs.at(s0).at(2)
        let pB0 = segs.at(s0).at(3)

        // walk forward from the B end
        let fwd = ()
        let cur = eB0
        let alive = true
        while alive {
          alive = false
          for nb in adj.at(str(cur), default: ()) {
            if not used.at(nb) {
              used.at(nb) = true
              if segs.at(nb).at(0) == cur {
                fwd.push(segs.at(nb).at(3))
                cur = segs.at(nb).at(2)
              } else {
                fwd.push(segs.at(nb).at(1))
                cur = segs.at(nb).at(0)
              }
              alive = true
              break
            }
          }
        }

        // walk backward from the A end (collected, then reversed)
        let bwd = ()
        let cur2 = eA0
        let alive2 = true
        while alive2 {
          alive2 = false
          for nb in adj.at(str(cur2), default: ()) {
            if not used.at(nb) {
              used.at(nb) = true
              if segs.at(nb).at(0) == cur2 {
                bwd.push(segs.at(nb).at(3))
                cur2 = segs.at(nb).at(2)
              } else {
                bwd.push(segs.at(nb).at(1))
                cur2 = segs.at(nb).at(0)
              }
              alive2 = true
              break
            }
          }
        }

        // Keep both ends of the seed segment between the backward and
        // forward walks. Omitting pB0 made the first link skip one contour
        // vertex and could jump across more than one grid cell.
        let poly = bwd.rev() + (pA0, pB0) + fwd
        if poly.len() >= 2 { polylines.push(poly) }
      }
    }
  }
  if with-count { (polylines, level-count) } else { polylines }
}
