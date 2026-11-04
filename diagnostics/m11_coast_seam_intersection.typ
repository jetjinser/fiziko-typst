// Isolate the mass-1 cyclic-seam thin cut using the exact source 16.16
// q cubic/ray and the current Typst trace's q cubic/ray.
#import "../intersection.typ": raw-intersections, intersection-times

#let fixed(whole, high, low) = whole * 65536 + high * 256 + low
#let pair(high, low) = high * 256 + low

#let source-q = (
  (fixed(361, 17, 84), pair(38, 66)),
  (fixed(368, 73, 106), pair(37, 140)),
  (fixed(375, 129, 127), pair(36, 214)),
  (fixed(382, 185, 149), pair(36, 32)),
)
#let source-ray = (
  (fixed(371, 229, 117), pair(36, 33)),
  (fixed(375, 129, 128), pair(36, 33)),
  (fixed(379, 29, 138), pair(36, 33)),
  (fixed(382, 185, 149), pair(36, 33)),
)

#let typst-q = (
  (23598077, 9793),
  (24070921, 9612),
  (24543766, 9430),
  (25016610, 9249),
)
#let midpoint = int(calc.round((typst-q.first().at(0)
  + typst-q.last().at(0)) / 2))
#let third = int(calc.round((typst-q.last().at(0) - midpoint) / 3))
#let two-thirds = int(calc.round(2 * (typst-q.last().at(0) - midpoint) / 3))
#let typst-ray = (
  (midpoint, 9249),
  (midpoint + third, 9249),
  (midpoint + two-thirds, 9249),
  (typst-q.last().at(0), 9249),
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
  <m11-coast-seam-intersection>
