#import "../fiziko.typ": pt, stroke-ink

// Experimental source-brush call-count probe. This samples each source knot
// ellipse at 96 points; MetaPost uses an eight-segment cubic fullcircle.
#let min-stroke = 0.2 * pt
#let step = 8 * min-stroke
#let count = int(calc.floor((2 * 1.25 - 2 * min-stroke) / step)) + 1
#let ring-counts = range(count).map(i => {
  let diameter = 2 * 1.25 - i * step
  let pts = range(96).map(j => {
    let a = 360 * j / 96
    (diameter / 2 * calc.cos(a),
     diameter / (2 * calc.sin(60)) * calc.sin(a))
  })
  let result = stroke-ink(pts, t => min-stroke *
    (1 / 2 + calc.sin(60) * calc.abs(calc.sin(360 * t))),
    closed: true, per: 0, min-w: min-stroke, period: 6 * min-stroke,
    _with-rng: true)
  result.at(1)
})

#metadata(ring-counts) <wood-knot-ring-counts>
