#import "../intersection.typ": intersection-times, raw-intersections

#let fixed(whole, high, low) = whole * 65536 + high * 256 + low
#let pair(high, low) = high * 256 + low
#let curves = (
  (
    (pair(8700, 54), pair(42, 128)),
    (pair(8793, 14), pair(41, 203)),
    (pair(8885, 230), pair(41, 22)),
    (pair(8978, 190), pair(40, 97)),
  ),
  (
    (pair(8978, 190), pair(40, 97)),
    (pair(11971, 167), pair(40, 97)),
    (pair(14964, 144), pair(40, 96)),
    (pair(17957, 121), pair(40, 96)),
  ),
  (
    (pair(17957, 121), pair(40, 96)),
    (pair(18051, 73), pair(41, 22)),
    (pair(18145, 25), pair(41, 204)),
    (pair(18238, 233), pair(42, 130)),
  ),
)
#let ray1 = (
  (pair(13469, 144), pair(40, 97)),
  (pair(15059, 88), pair(40, 97)),
  (pair(16649, 33), pair(40, 97)),
  (pair(18238, 233), pair(40, 97)),
)
#let ray2 = (
  (pair(13469, 144), pair(40, 97)),
  (pair(11879, 199), pair(40, 97)),
  (pair(10289, 255), pair(40, 97)),
  (pair(8700, 54), pair(40, 97)),
)
#let x = (
  fixed(238, 78, 10), fixed(242, 7, 112),
  fixed(245, 192, 214), fixed(249, 122, 60),
)
#let y = (
  fixed(0, 41, 114), fixed(0, 41, 23),
  fixed(0, 40, 188), fixed(0, 40, 97),
)
#let ray-x = (
  fixed(203, 100, 9), fixed(218, 192, 197),
  fixed(234, 29, 128), fixed(249, 122, 60),
)
#let q = range(4).map(i => (x.at(i), y.at(i)))
#let base-level = fixed(0, 40, 97)
#let results = range(17).map(i => {
  let offset = i - 8
  let level = base-level + offset
  let ray = range(4).map(k => (ray-x.at(k), level))
  let raw = raw-intersections(ray, (q,))
  (offset: offset, direct: raw.at(0), reverse: raw.at(1),
    selected: intersection-times(ray, (q,)))
})

#metadata((m11: results, s104: (
  ray1: (raw: raw-intersections(ray1, curves), selected: intersection-times(ray1, curves)),
  ray2: (raw: raw-intersections(ray2, curves), selected: intersection-times(ray2, curves)),
))) <metapost-intersection-sweep>
