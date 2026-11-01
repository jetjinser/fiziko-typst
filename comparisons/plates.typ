// Native drawing counterparts. All differing numeric inputs come from the
// manifest and are recorded in each report; no parameter fitting occurs here.
#import "../fiziko.typ": *
#import "globe-coasts.typ": upstream-landmasses

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
      rng: "metapost",
      samples: i("samples"), seed: seed, with-rng: true)
    let (large, _) = sphere-latitude(30, latitude: 45, center: (70,28),
      rng: "metapost", samples: i("samples"), seed: seed,
      rng-offset: cursor, with-rng: true)
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
  } else if case == "M8" {
    (l-hopital-pulley(6, 2, 5.5, at: (8,6), seed: seed)
    + l-hopital-pulley(3, 2.5, 3, at: (58,6), seed: seed))
  } else if case == "M9" {
    let p1 = wooden-thing(((0,0),(55,0),(55,33),(0,33)), angle: 0,
      cell: 1, source-field: true, seed: seed, rng-offset: 0, with-rng: true)
    let p2 = wooden-thing(((55,0),(110,0),(110,33),(55,33)), angle: 90,
      cell: 1, source-field: true, seed: seed, rng-offset: p1.at(1), with-rng: true)
    let p3 = wooden-thing(((0,33),(55,33),(55,66),(0,66)), angle: 90,
      cell: 1, source-field: true, seed: seed, rng-offset: p2.at(1), with-rng: true)
    let p4 = wooden-thing(((55,33),(110,33),(110,66),(55,66)), angle: 0,
      cell: 1, source-field: true, seed: seed, rng-offset: p3.at(1), with-rng: true)
    combine((p1.at(0), p2.at(0), p3.at(0), p4.at(0)))
  } else if case == "M10" {
    (stroke-path(((8,6),(30,6)), stroke: 0.6pt + black, per: 0)
    + combine(range(5).map(i => stroke-path(((11+4.5*i,6),(9.5+4.5*i,3.5)),
        stroke: 0.35pt + black, per: 0)))
    + spring((19,6),(19,30), coils: 7, rad: 1.2, lead: 3)
    + weight(14, r: 3, at: (19,30), seed: seed)
    + vector((19,45.5),(19,54), w: 0.07, head: 1.4, seed: seed)
    + tag([k],(25,17)) + tag([mg],(23.5,52))
    + lens(20, 2.087, rim: 1.6, at: (72,30))
    + stroke-path(((51,30),(94,30)), stroke: (paint: black, thickness: 0.35pt, dash: "dashed"), per: 0)
    + vector((52,24),(68.5,24), w: 0.07, head: 1.4, seed: seed)
    + vector((74.5,24),(86,33.6), w: 0.07, head: 1.4, seed: seed)
    + stroke-path(circle-pts(0.4,24,center:(82,30)), stroke: 0.35pt + black, closed: true, per: 0)
    + tag([F],(84.5,36)) + tag([f],(78.6,32.8)) + tag([i],(75.6,27.7)))
  } else if case == "M11" {
    let wa = range(97).map(i => (86 + 32 * i / 96,
      22 + 6 * calc.sin(720 * i / 96 * 1deg)))
    let wb = range(97).map(i => (86 + 32 * i / 96,
      22 - 6 * calc.sin(720 * i / 96 * 1deg)))
    (globe(30, rotation: (0,0), lands: upstream-landmasses,
      shading: "latitude",
      center: (19,22))
    + eye(at: (62,22), size: (18,10), look: (0,0), lashes: 7, seed: seed)
    + strand-knot((wa,wb), widths: (0.8,0.8),
      layers: ((-1,1,-1,1),(1,-1,1,-1)), gap: 0,
      seed: seed, style: "tube")
    + stroke-path(circle-pts(10,128,center:(136,22)), stroke: 0.35pt + black, closed: true, per: 0)
    + refraction-path(((122,17),(128,17)), circle-pts(10,128,center:(136,22)), ior: 1.5))
  } else if case == "S102" {
    (tube(((7,32),(35,10),(56,31)), 3, hatch: none, per: 8, seed: seed)
    + sphere(26, center: (90,22), seed: seed, shadow-planes: (
        sphere-shadow-plane(((-4,-18),(-2,-18),(-2,18),(-4,18)), 12),
      )))
  } else if case == "S103" {
    (solid-surface(((4,20),(30,17),(53,21)))
    + solid(((62,9),(82,9),(82,32),(62,32)), angle: 45, style: "opaque")
    + solid(((87,9),(105,9),(105,32),(87,32)), angle: -45, style: "glass")
    + gradient-shade(((108,9),(117,9),(117,32),(108,32)), angle: 90, seed: seed))
  } else if case == "S104" {
    // The source frame flips the vertical axis in P(); its +30° MetaPost
    // rotation maps to -30° in Typst's page coordinates.
    (flat-surface(((8,8),(56,13),(50,36),(5,31)), (0,0,-1), angle: -30,
      rng: "metapost", seed: seed)
    + stroke-path(((8,8),(56,13),(50,36),(5,31)), stroke: 0.35pt + black, closed: true, per: 0)
    + flat-surface(((65,8),(114,13),(108,36),(62,31)), (1,0,1), angle: -30,
        style: "stipples")
    + stroke-path(((65,8),(114,13),(108,36),(62,31)), stroke: 0.35pt + black, closed: true, per: 0))
  } else if case == "S105" {
    (wood(5,29,39,12, cell: 1, source-field: true, seed: seed)
    + wooden-surface(((60,18),(84,12),(112,18))))
  } else if case == "S106" {
    (weight-standing(18, r: 3, at: (36,31), seed: seed)
    + weight(18, r: 3, at: (84,13), seed: seed)
    + stroke-path(((10,31),(62,31)), stroke: 0.35pt + black, per: 0)
    + stroke-path(((64,13),(112,13)), stroke: 0.35pt + black, per: 0))
  } else if case == "S107" {
    let plate = ((83,8),(113,11),(108,36),(87,31))
    (pulley-wheel(23, center: (22,22), seed: seed)
    + wheel(23, center: (61,22), style: "source", seed: seed)
    + stroke-path(plate, stroke: 0.35pt + black, closed: true, per: 0)
    + stroke-path(circle-pts(0.75,24,center:polygon-centroid(plate)),
        stroke: 0.35pt + black, closed: true, per: 0))
  } else if case == "S108" {
    (lens(24,3.068,rim:1.5,at:(15,21))
    + lens(24,1.5,rim:3.068,at:(34,21))
    + lens(24,1.5,rim:1.5,right-sag:3.068,at:(53,21))
    + stroke-path(((70,30),(87,11),(105,30)), stroke: 0.35pt + black, per: 0)
    + vector((87,11),(89,9), w: 0.01, head: 1.2)
    + stroke-path(((104,32),(111,20),(119,32)), stroke: 0.35pt + black, per: 0)
    + mark-angle((104,32),(111,20),(119,32),r: 5)
    + tag($a$,(111,27)))
  } else {
    panic("Unknown comparison plate: " + case)
  }
)
