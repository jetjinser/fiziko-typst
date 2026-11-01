// Native drawing counterparts. All differing numeric inputs come from the
// manifest and are recorded in each report; no parameter fitting occurs here.
#import "../fiziko.typ": *

#let case = sys.inputs.at("case")
#let n(key) = float(sys.inputs.at(key))
#let i(key) = int(sys.inputs.at(key))
#let seed = i("seed")
#let width = n("width")
#let height = n("height")
#set page(width: width * 1mm, height: height * 1mm, margin: 0pt)
#set text(font: "New Computer Modern", size: 10.5pt)

#canvas(width, height,
  if case == "M1" {
    (stroke-path(((6,36),(38,16),(72,34),(104,14)), stroke: 0.6pt + black, per: i("per"))
    + stroke-path(offset-path(((6,36),(38,16),(72,34),(104,14)),
      t => 7 * calc.sin(calc.pi * t), closed: false, per: i("per")),
      stroke: (paint: black, thickness: 0.5pt, dash: "dashed"), per: 0))
  } else if case == "M2" {
    let path = ((6,36),(38,16),(72,34),(104,14))
    (stroke-path(path, stroke: (paint: black, thickness: 0.35pt, dash: "dotted"), per: 24)
    + stroke-ink(path, t => n("amplitude") * pt * calc.pow(calc.sin(calc.pi * t), n("exponent")),
      closed: false, per: i("per"), seed: seed))
  } else if case == "M3" {
    let (small, cursor) = sphere-latitude(20, latitude: -60, center: (36,28),
      samples: i("samples"), seed: seed, with-rng: true)
    let (large, _) = sphere-latitude(30, latitude: 45, center: (70,28),
      samples: i("samples"), seed: seed, rng-offset: cursor, with-rng: true)
    small + large
  } else if case == "M4" {
    tube(arc-pts(42,205,335,n: 40,center: (55,68)), 6,
      per: i("per"), seed: seed, max-w: n("max_width") * pt)
  } else if case == "M5" {
    (stroke-ink(((14,6),(78,6)), 0.6 * pt, closed: false, per: 8, seed: seed)
    + combine(range(9).map(j => stroke-path(((20+6.5*j,6),(16.5+6.5*j,1.5)),
      stroke: 0.2pt + black, per: 4)))
    + tube(((35,6),(59.4,51.9)), 1, per: 8, seed: seed)
    + sphere(26, center: (59.4,51.9), seed: i("sphere_seed"))
    + vector((59.4,66.5),(59.4,78), w: 0.5, head: 2.8)
    + mark-angle((35,20),(35,6),(59.4,51.9),r: 7.5)
    + tag($A$,(31,3.5),anchor: bottom + right)
    + tag($theta$,(37.6,16.3)) + tag($l$,(51.2,26.9))
    + tag($m$,(76.4,49.9)) + tag($m g$,(65,76)))
  } else if case == "M6" {
    (tube(circle-pts(24,96,center: (32,31)),
      t => 3.5 - 1.8 * calc.sin(10 * calc.pi * t), closed: true, per: i("per"), seed: seed)
    + tube(((85,10),(85,52)), t => (1-t)*9, per: 8, seed: seed))
  } else if case == "M7" {
    tube(((6,32),(40,14),(74,32),(104,16)), 5,
      hatch: "t", per: i("per"), period: n("period") * pt, seed: seed)
  } else if case == "C1" {
    sphere(26, center: (55,28), samples: i("samples"), seed: seed)
  } else if case == "S101" {
    (stroke-stipple-brush(((5,35),(26,13),(48,32)), t => 0.3 * pt * calc.sin(calc.pi * t),
      closed: false, per: i("per"), seed: seed, density: n("brush_density"))
    + sphere-stipple-rings(22, center: (70,22), seed: seed, density: n("sphere_density"))
    + tube(((89,33),(103,10),(115,28)), 3, hatch: "s", per: i("per"),
      seed: seed, dot-density: n("tube_density")))
  } else {
    panic("Unknown comparison plate: " + case)
  }
)
