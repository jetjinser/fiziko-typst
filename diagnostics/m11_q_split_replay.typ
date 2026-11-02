// Port fixed-point q-cubic subdivision into Typst and compare each child
// control point with the paired MetaPost trace.
#import "../fiziko.typ": _mp-cubic-path-split, _mp-rounded
#import "../build/m11-q-split-cases.typ": m11-q-split-cases

#let quantize-curves(curves) = curves.map(segment => segment.map(point => (
  _mp-rounded(point.at(0)), _mp-rounded(point.at(1)))) )

#let results = m11-q-split-cases.map(case => {
  let result = _mp-cubic-path-split(case.segments, case.t)
  let left-match = quantize-curves(result.left) == quantize-curves(case.left)
  let right-match = quantize-curves(result.right) == quantize-curves(case.right)
  (t: case.t, left-match: left-match, right-match: right-match)
})

#metadata(results) <m11-q-split-replay>
