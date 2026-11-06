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

// Exact M11 landmass-1 first-divergence input from the brush trace: the ray's
// final point is the width cubic's initial point, and the target is that
// initial width. MetaPost's forward/reverse selection returns an interior hit.
#let coast-start-width = fixed(0, 36, 33)
#let coast-q = (
  (fixed(185, 131, 46), coast-start-width),
  (fixed(186, 137, 4), fixed(0, 36, 48)),
  (fixed(187, 142, 218), fixed(0, 36, 64)),
  (fixed(188, 148, 176), fixed(0, 36, 79)),
)
#let coast-ray = (
  (fixed(237, 183, 147), coast-start-width),
  (fixed(220, 80, 199), coast-start-width),
  (fixed(202, 233, 250), coast-start-width),
  (fixed(185, 131, 46), coast-start-width),
)
#let coast-start-width-result = (
  raw: raw-intersections(coast-ray, (coast-q,)),
  selected: intersection-times(coast-ray, (coast-q,)),
)

// S104 row -7.27608, node 141: MetaPost's forward path misses, while the
// reversed q path reports a near-endpoint hit at ray time 0, q time 0.5.
#let endpoint-q = (
  (1864409, 11968), (2070251, 11609),
  (2276094, 11251), (2481936, 10892),
)
#let endpoint-ray = (
  (2173173, 11425), (2070252, 11425),
  (1967330, 11425), (1864409, 11425),
)
#let endpoint-result = (
  raw: raw-intersections(endpoint-ray, (endpoint-q,)),
  selected: intersection-times(endpoint-ray, (endpoint-q,)),
)

#metadata((m11: results, s104: (
  ray1: (raw: raw-intersections(ray1, curves), selected: intersection-times(ray1, curves)),
  ray2: (raw: raw-intersections(ray2, curves), selected: intersection-times(ray2, curves)),
), m11-coast-start-width: coast-start-width-result,
  s104-endpoint: endpoint-result)) <metapost-intersection-sweep>
