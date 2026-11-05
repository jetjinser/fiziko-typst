// Source-fixed S104 row used to compare MetaPost firstIntersectionTimes
// against the general fixed-point cubic solver.
#import "../intersection.typ": cubic-intersection, path-intersection

#let source-point(whole, high, low) = whole * 65536 + high * 256 + low
#let points = (
  (source-point(70, 169, 157), source-point(77, 9, 123)),
  (source-point(181, 104, 251), source-point(-4, 187, 53)),
  (source-point(134, 21, 27), source-point(-52, 197, 228)),
  (source-point(30, 179, 22), source-point(24, 211, 169)),
)
#let post = (
  (source-point(107, 148, 18), source-point(50, 68, 185)),
  (source-point(165, 162, 91), source-point(-20, 190, 197)),
  (source-point(99, 159, 25), source-point(-26, 31, 208)),
  (source-point(44, 5, 67), source-point(42, 58, 239)),
)
#let pre = (
  (source-point(144, 126, 134), source-point(23, 127, 246)),
  (source-point(149, 219, 187), source-point(-36, 194, 84)),
  (source-point(65, 41, 24), source-point(-1, 121, 189)),
  (source-point(57, 87, 112), source-point(59, 162, 53)),
)
#let curves = range(4).map(i => (
  points.at(i), post.at(i), pre.at(i),
  points.at(calc.rem(i + 1, 4)),
))
#let ray = (
  (source-point(30, 179, 22), source-point(-7, 158, 242)),
  (source-point(80, 239, 184), source-point(-7, 158, 242)),
  (source-point(131, 44, 89), source-point(-7, 158, 242)),
  (source-point(181, 104, 251), source-point(-7, 158, 242)),
)
#let reverse-ray = ray.rev()
#let fixed-mix(a, b, t) = a + int(calc.round((b - a) * t))
#let fixed-mix-point(a, b, t) = (
  fixed-mix(a.at(0), b.at(0), t), fixed-mix(a.at(1), b.at(1), t),
)
#let eval-cubic(curve, t) = {
  let a = fixed-mix-point(curve.at(0), curve.at(1), t)
  let b = fixed-mix-point(curve.at(1), curve.at(2), t)
  let c = fixed-mix-point(curve.at(2), curve.at(3), t)
  let d = fixed-mix-point(a, b, t)
  let e = fixed-mix-point(b, c, t)
  fixed-mix-point(d, e, t)
}
#let direct-edge2 = cubic-intersection(ray, curves.at(2))
#let reverse-edge1 = cubic-intersection(reverse-ray, curves.at(1))
#let fixed-divide(a, b) = {
  let sign = if (a < 0) != (b < 0) { -1 } else { 1 }
  sign * calc.floor((calc.abs(a) + calc.abs(b) / 2) / calc.abs(b))
}
#let line-cubic(a, b) = {
  let c1 = (0, 1).map(axis => a.at(axis)
    + fixed-divide(b.at(axis) - a.at(axis), 3))
  let c2 = (0, 1).map(axis => a.at(axis)
    + fixed-divide(2 * (b.at(axis) - a.at(axis)), 3))
  (a, c1, c2, b)
}
#let generated-curves = range(4).map(i =>
  line-cubic(points.at(i), points.at(calc.rem(i + 1, 4))))
#let generated-ray = line-cubic(ray.at(0), ray.at(3))
#let generated-ray-reverse = generated-ray.rev()
#let generated-hits = generated-curves.map(curve => cubic-intersection(generated-ray, curve))
#let generated-reverse-hits = generated-curves.map(curve => cubic-intersection(generated-ray-reverse, curve))
#metadata((
  direct: path-intersection(ray, curves),
  reverse: path-intersection(reverse-ray, curves),
  direct-edges: curves.map(curve => cubic-intersection(ray, curve)),
  reverse-edges: curves.map(curve => cubic-intersection(reverse-ray, curve)),
  hit-points: (eval-cubic(ray, direct-edge2.at(0)),
    eval-cubic(reverse-ray, reverse-edge1.at(0))),
  generated-hits: generated-hits,
  generated-reverse-hits: generated-reverse-hits,
)) <s104-clip-intersection-probe>
