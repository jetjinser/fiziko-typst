// Small, text-free regression plates. Parameters and seeds are fixed here;
// these are Typst behavior baselines, not calibrated upstream comparisons.
#import "../fiziko.typ": *

#let case = sys.inputs.at("case")
#set page(width: 120mm, height: 62mm, margin: 0pt)

#canvas(120, 62,
  if case == "brush" {
    let path = ((6, 36), (38, 16), (72, 34), (104, 14))
    (stroke-ink(path, t => 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2),
      closed: false, per: 24, seed: 1)
    + stroke-ink(((8, 52), (16, 42), (24, 52)), 0.55,
      closed: false, per: 0, seed: 1)
    + stroke-ink(((32, 48), (32.5, 48)), 0.05,
      closed: false, per: 0, seed: 1)
    + stroke-ink(circle-pts(7, 48, center: (70, 49)),
      t => (0.25 + 0.2 * calc.sin(360 * t * 1deg)) * pt,
      closed: true, per: 0, seed: 1))
  } else if case == "sphere-concentric" {
    (sphere(26, center: (32, 31), seed: 1)
    + sphere(18, center: (82, 31), light: (0.6, -0.3, 0.7), seed: 5))
  } else if case == "sphere-latitude" {
    (sphere-latitude(20, latitude: -60, center: (32, 31), samples: 180, seed: 1)
    + sphere-latitude(30, latitude: 45, center: (78, 31), samples: 180, seed: 1))
  } else if case == "tube-longitudinal" {
    tube(arc-pts(42, 205, 335, n: 40, center: (55, 68)), 6, per: 4, seed: 1)
  } else if case == "tube-variable" {
    (tube(circle-pts(24, 96, center: (32, 31)),
      t => 3.5 - 1.8 * calc.sin(360 * 5 * t * 1deg),
      closed: true, per: 2, seed: 1)
    + tube(((85, 10), (85, 52)), t => (1 - t) * 9, per: 8, seed: 1))
  } else if case == "tube-transverse" {
    tube(((6, 32), (40, 14), (74, 32), (104, 16)), 5,
      hatch: "t", per: 96, seed: 1)
  } else if case == "stipple-brush" {
    (stroke-stipple-brush(((5, 35), (26, 13), (48, 32)),
      t => 0.3 * pt * calc.sin(calc.pi * t), closed: false, per: 48, seed: 1)
    + stroke-stipple-brush(((68, 25), (76, 25)), 0.11 * pt,
      dot-size: 0.6 * pt, track-spacing: 0.9 * pt, closed: false, per: 0, seed: 4)
    + stroke-stipple-brush(circle-pts(10, 48, center: (94, 31)),
      0.3 * pt, closed: true, per: 0, seed: 1))
  } else if case == "stipple-sphere" {
    sphere-stipple-rings(22, center: (32, 31), seed: 1)
  } else if case == "stipple-field" {
    sphere-stipple(22, center: (32, 31), seed: 1)
  } else if case == "stipple-tube" {
    (tube(((12, 43), (36, 15), (62, 38)), 3, hatch: "s", per: 48, seed: 1)
    + tube(((78, 44), (100, 16)), t => 0.9 + 1.6 * (1 - t),
      hatch: "s", per: 12, seed: 5))
  } else {
    panic("Unknown regression case: " + case)
  }
)
