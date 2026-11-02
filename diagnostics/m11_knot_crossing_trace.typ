// Compare the source's knotFromStrands path times with the sampled-polyline
// crossing detector used by strand-knot.
#import "../fiziko.typ": _dist, _dot, _polyline-lengths, _sub
#import "../solve.typ": line-intersect
#import "../comparisons/m11-knot-paths.typ": upstream-m11-knot-paths

#let wa = upstream-m11-knot-paths.wa
#let wb = upstream-m11-knot-paths.wb
#let times = range(wa.len()).map(i => i / upstream-m11-knot-paths.path-step)
#let lengths-a = _polyline-lengths(wa)
#let lengths-b = _polyline-lengths(wb)
#let crossings = ()
#for ai in range(wa.len() - 1) {
  let a = wa.at(ai)
  let da = _sub(wa.at(ai + 1), a)
  if _dist(a, wa.at(ai + 1)) < 1e-9 { continue }
  for bi in range(wb.len() - 1) {
    let b = wb.at(bi)
    let db = _sub(wb.at(bi + 1), b)
    if _dist(b, wb.at(bi + 1)) < 1e-9 { continue }
    let p = line-intersect(a, da, b, db)
    if p == none { continue }
    let fa = _dot(_sub(p, a), da) / _dot(da, da)
    let fb = _dot(_sub(p, b), db) / _dot(db, db)
    if fa >= -1e-6 and fa < 1 - 1e-6 and fb >= -1e-6 and fb < 1 - 1e-6 {
      let ta = times.at(ai) * (1 - fa) + times.at(ai + 1) * fa
      let tb = times.at(bi) * (1 - fb) + times.at(bi + 1) * fb
      let sa = lengths-a.at(ai) + fa * _dist(a, wa.at(ai + 1))
      let sb = lengths-b.at(bi) + fb * _dist(b, wb.at(bi + 1))
      let total-a = lengths-a.last()
      let total-b = lengths-b.last()
      if (sa > 1e-5 and sa < total-a - 1e-5 and
          sb > 1e-5 and sb < total-b - 1e-5 and
          not crossings.any(x => calc.abs(x.at(0) - ta) < 1e-4)) {
        crossings.push((ta, tb, p))
      }
    }
  }
}
#metadata(crossings) <m11-knot-crossings>
