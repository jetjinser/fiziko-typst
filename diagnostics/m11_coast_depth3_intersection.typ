// Isolate the near-endpoint cut in mass 1's depth-3 right coast branch.
// Coordinates are 16.16 q-template units copied from source and Typst traces.
#import "../intersection.typ": raw-intersections, intersection-times

#let source-q = (
  (23659020, 9796), (24147323, 9608),
  (24635625, 9421), (25123928, 9233),
)
#let typst-q = (
  (23666483, 9793), (24151715, 9607),
  (24636947, 9420), (25122179, 9234),
)
#let source-ray = (
  (22875674, 9793), (23648154, 9793),
  (24420634, 9793), (25193114, 9793),
)
#let typst-ray = (
  (22841404, 9793), (23602347, 9793),
  (24363291, 9793), (25124234, 9793),
)

#let cases = (
  (name: "source/source", q: source-q, ray: source-ray),
  (name: "source/typst-ray", q: source-q, ray: typst-ray),
  (name: "typst/source-ray", q: typst-q, ray: source-ray),
  (name: "typst/typst", q: typst-q, ray: typst-ray),
)
#metadata(cases.map(item => (name: item.name,
  raw: raw-intersections(item.ray, (item.q,)),
  selected: intersection-times(item.ray, (item.q,)))))
  <m11-coast-depth3-intersection>
