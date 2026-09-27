// contour.typ — marching squares with exact chain stitching, for fiziko.typ.
//
// Given a scalar field f over a rectangle, produce the iso-lines as polylines.
// Segments are identified by the *grid edges* they cross (each segment has
// exactly one horizontal and one vertical edge), so chaining is a graph walk
// with integer keys — no floating-point endpoint matching.

/// Iso-lines of `f` over the rectangle (x0, y0, w, h) at multiples of `step`.
/// Returns an array of polylines, each an array of (x, y) float points.
#let marching-squares(f, x0, y0, w, h, step: 1.0, nx: 40, ny: 24) = {
  let dx = w / nx
  let dy = h / ny
  let V = range(ny + 1).map(j => range(nx + 1).map(i => f(x0 + i * dx, y0 + j * dy)))
  let flat = ()
  for row in V { flat += row }
  let l0 = calc.ceil(calc.min(..flat) / step - 1e-9)
  let l1 = calc.floor(calc.max(..flat) / step + 1e-9)
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
  if l1 >= l0 {
    for li in range(l1 - l0 + 1) {
      let L = (l0 + li) * step
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
  polylines
}
