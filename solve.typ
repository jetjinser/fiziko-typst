// solve.typ — a tiny linear solver for fiziko.typ.
//
// MetaPost solves geometric constraints by writing equations with `whatever`
// (a free variable in a linear system). This module provides the modern
// equivalent: Gauss–Jordan elimination for small dense systems, and a line
// intersection built on it — enough for constructions like the centre of
// fisiko's L'Hôpital pulley.

/// MetaPost's "Pythagorean addition"/"subtraction": `a ++ b`, `a +-+ b`.
#let pyth-add(a, b) = calc.sqrt(a * a + b * b)
#let pyth-sub(a, b) = calc.sqrt(a * a - b * b)

/// Solve A·x = b by Gauss–Jordan elimination with partial pivoting.
/// `A` is an array of n rows (each an array of n numbers), `b` has length n.
/// Returns the solution vector, or none when the system is singular.
#let solve-linear(A, b, eps: 1e-12) = {
  let n = A.len()
  let M = range(n).map(i => A.at(i) + (b.at(i),))
  for col in range(n) {
    let piv = col
    for r in range(col + 1, n) {
      if calc.abs(M.at(r).at(col)) > calc.abs(M.at(piv).at(col)) { piv = r }
    }
    if calc.abs(M.at(piv).at(col)) < eps { return none }
    if piv != col {
      let t = M.at(col)
      M.at(col) = M.at(piv)
      M.at(piv) = t
    }
    let row = M.at(col)
    let pv = row.at(col)
    for j in range(col, n + 1) { row.at(j) = row.at(j) / pv }
    M.at(col) = row
    for r in range(n) {
      if r != col {
        let f = M.at(r).at(col)
        if f != 0 {
          let rr = M.at(r)
          for j in range(col, n + 1) { rr.at(j) = rr.at(j) - f * row.at(j) }
          M.at(r) = rr
        }
      }
    }
  }
  range(n).map(i => M.at(i).at(n))
}

/// Intersection of the lines p1 + s·d1 and p2 + t·d2 (planar, exact).
/// Returns none when the lines are parallel.
#let line-intersect(p1, d1, p2, d2, eps: 1e-12) = {
  let sol = solve-linear(
    ((d1.at(0), -d2.at(0)), (d1.at(1), -d2.at(1))),
    (p2.at(0) - p1.at(0), p2.at(1) - p1.at(1)),
    eps: eps,
  )
  if sol == none {
    none
  } else {
    (p1.at(0) + d1.at(0) * sol.at(0), p1.at(1) + d1.at(1) * sol.at(0))
  }
}
