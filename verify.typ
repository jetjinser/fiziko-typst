#import "fiziko.typ": *
#import "fiziko.typ": _ink-loops, _frame, _dist, _add, _sub, _mul, _unit, _cross, _tube-layout, _pulley-geometry, _wood-field, _head-pts, _angle-arc, _spring-pts, _lens-outline, _weight-parts, _dir-angle, _ray-hit, _strand-fragments, trace-refraction, globe-project
#import "solve.typ": solve-linear, line-intersect
#import "contour.typ": marching-squares

#let dist(a, b) = calc.sqrt(calc.pow(a.at(0) - b.at(0), 2) + calc.pow(a.at(1) - b.at(1), 2))

// -- 1. arc smoothness ------------------------------------------------------
#let arc = arc-pts(42, 205, 335, n: 60, center: (55, 40))
#let steps = range(1, arc.len()).map(i => dist(arc.at(i), arc.at(i - 1)))

// -- 2. circle sanity -------------------------------------------------------
#let circ = circle-pts(15, 300, center: (30, 28))
#let radii = circ.map(p => dist(p, (30, 28)))

// -- 3. offset side band: this arc's normal points inward, radius 42-6 -----
#let fr = _frame(arc, false)
#let disp = fr.enumerate().map(((i, e)) => (_add(e.at(0), _mul(e.at(1), 6.0)), e.at(1)))
#let ws = range(fr.len()).map(_ => 0.5 * pt)
#let loops = _ink-loops(disp, ws, false, 0.3 * pt, 1.4)
#let bandradii = loops.map(lp => lp.map(p => dist(p, (55, 40)))).flatten()

// -- 4. variable-width brush on a straight line: half-width law ------------
#let line = ((0, 50), (100, 50))
#let fr2 = _frame(resample(line, per: 40, closed: false), false)
#let law(t) = 3 * pt * calc.pow(calc.sin(180 * t * 1deg), 2)
#let ws2 = fr2.enumerate().map(((i, e)) => law(i / (fr2.len() - 1)))
#let loops2 = _ink-loops(fr2, ws2, false, 0.3 * pt, 1.4)
#let ys = loops2.map(lp => lp.map(p => p.at(1))).flatten()

// -- 5. tube layout: tapered longitudinal --------------------------------
#let Lcone = _tube-layout(((0, 0), (60, 0)), t => (1 - t) * 10,
                           hatch: "l", spacing: 1.8, per: 8)
#let cone-r0 = (Lcone.rfun)(0.0)
#let cone-r1 = (Lcone.rfun)(1.0)
#let cone-us = Lcone.inner.map(it => it.u)
#let cone-w0 = (Lcone.inner.at(0).w)(0.0)
#let cone-w1 = (Lcone.inner.at(0).w)(1.0)

// -- 6. transverse hatching: ink budget, spacing, printable clamp --------
#let Ltr = _tube-layout(((0, 0), (60, 0)), 6, hatch: "t",
                        spacing: 2.2, coverage: 0.4, per: 8)
#let tr0 = Ltr.trans.at(0)
#let tr1 = Ltr.trans.at(1)
#let tr-gap = (tr1.t - tr0.t) * 60
#let tr-profile-mid = (tr0.profile)(0.5)
#let tr-cross-width = dist(tr0.pts.first(), tr0.pts.last())
#let Lcl = _tube-layout(((0, 0), (60, 0)), 6, hatch: "t",
                        spacing: 0.05, coverage: 0.4, per: 8)

// -- 7. solve.typ -----------------------------------------------------------
#let slv = solve-linear(((2, 1, -1), (-3, -1, 2), (-2, 1, 2)), (8, -11, -3))
#let slv-err = if slv == none { 999.0 } else {
  calc.max(calc.abs(slv.at(0) - 2), calc.abs(slv.at(1) - 3), calc.abs(slv.at(2) + 1))
}
#let slv-sing = if solve-linear(((1, 2), (2, 4)), (1, 2)) == none { 1.0 } else { 0.0 }
#let par-none = if line-intersect((0, 0), (1, 0), (0, 1), (1, 0)) == none { 1.0 } else { 0.0 }

// -- 8. L'Hôpital's pulley: geometry + physics ------------------------------
#let pul(G, l, m) = {
  let AB = G.B.at(0)
  let uB = ((G.B.at(0) - G.D.at(0)) / G.BD, (G.B.at(1) - G.D.at(1)) / G.BD)
  let e = _sub(G.E, G.D)
  let t1 = l * (AB - G.x1) / (G.x1 * G.BD)
  (
    ad: calc.abs(_dist(G.D, G.A) - l),
    quad: calc.abs(2 * AB * G.x1 * G.x1 - l * l * G.x1 - l * l * AB),
    eq: calc.abs(t1 * G.y1 / l + G.y1 / G.BD - 1),
    tang-dc: calc.abs(calc.abs(e.at(0)) - G.r3),
    tang-db: calc.abs(calc.abs(e.at(0) * uB.at(1) - e.at(1) * uB.at(0)) - G.r3),
    t-dc: e.at(1),
    t-db: e.at(0) * uB.at(0) + e.at(1) * uB.at(1),
    y2: G.y2,
    BD: G.BD,
    r3: G.r3,
  )
}
#let P1 = pul(_pulley-geometry(6, 2, 11 / 2), 2, 11 / 2)
#let P2 = pul(_pulley-geometry(3, 5 / 2, 3), 5 / 2, 3)

// -- 9. wood grain: isolines satisfy the field, chains stay cell-local ------
#let fwood = _wood-field(0, 2.6, ((30, 20, 5, 0.9),))
#let wloops = marching-squares(fwood, 0, 0, 60, 40, step: 1, nx: 40, ny: 27)
#let wvals = wloops.map(lp => lp.map(p => {
  let v = fwood(p.at(0), p.at(1))
  calc.abs(v - calc.round(v))
})).flatten()
#let w-steps = wloops.map(lp => {
  if lp.len() < 2 { (0.0,) } else {
    range(1, lp.len()).map(i => _dist(lp.at(i), lp.at(i - 1)))
  }
}).flatten()
#let w-err = if wvals.len() > 0 { calc.max(..wvals) } else { 999.0 }
#let w-step = if w-steps.len() > 0 { calc.max(..w-steps) } else { 0.0 }

// -- 11. globe, knot gaps, and geometric optics ----------------------------
#let globe-centre = globe-project(37, -12, rotation: (37, -12))
#let globe-horizon = globe-project(90, 0)
#let globe-antipode = globe-project(180, 0)
#let strand-pieces = _strand-fragments(((0, 0), (10, 0)), (0, 10), ((5, 1),))
#let optics-boundary = circle-pts(10, 720)
#let refracted-ray = trace-refraction(((-15, 4), (-12, 4)), optics-boundary,
  ior: 1.5, bounces: 2, max-length: 30)
#let refracted-entry = _ray-hit((-12, 4), (1, 0), optics-boundary)
#let refracted-direction = _unit(_sub(refracted-ray.at(3), refracted-ray.at(2)))
#let snell-error = calc.abs(
  calc.abs(_cross(refracted-direction, refracted-entry.at(2)))
    - calc.abs(_cross((1, 0), refracted-entry.at(2))) / 1.5,
)
#let tir-ray = trace-refraction(((-5, 9), (0, 9)), optics-boundary,
  ior: 1.5, bounces: 1, max-length: 10)
#let tir-direction = _sub(tir-ray.at(3), tir-ray.at(2))

// -- 10. physics primitives -------------------------------------------------
#let hp = _head-pts((10, 5), (1, 0), 2.6)
#let h-mid = ((hp.at(0).at(0) + hp.at(1).at(0)) / 2,
              (hp.at(0).at(1) + hp.at(1).at(1)) / 2)
#let arc1 = _angle-arc((2, 3), (0, 10), (10, 0), r: 7)
#let arc-e0 = _sub(arc1.at(0), (2, 3))
#let arc-el = _sub(arc1.at(arc1.len() - 1), (2, 3))
#let arc-steps = range(1, arc1.len()).map(i => _dist(arc1.at(i), arc1.at(i - 1)))
#let sp = _spring-pts((0, 0), (0, 40), coils: 8, rad: 1.8, lead: 3)
#let sp-ys = sp.map(p => p.at(1))
#let lo = _lens-outline(20, 3.2, 0)
#let lo-xs = lo.map(p => p.at(0))
#let lo-ys = lo.map(p => p.at(1))
#let lc = _lens-outline(20, 1.2, 4)
#let lc-xs = lc.map(p => p.at(0))
#let wps = _weight-parts(14, 3)

#let metrics = (
  arc_step_min: calc.min(..steps),
  arc_step_max: calc.max(..steps),
  arc_expect: 42 * 130deg / 1deg * calc.pi / 180 / 60,
  circle_r_min: calc.min(..radii),
  circle_r_max: calc.max(..radii),
  band_r_min: calc.min(..bandradii),
  band_r_max: calc.max(..bandradii),
  band_expect_lo: 36 - 0.5 * 0.5 * pt,
  band_expect_hi: 36 + 0.5 * 0.5 * pt,
  band_loops: loops.len(),
  brush_y_min: calc.min(..ys),
  brush_y_max: calc.max(..ys),
  brush_expect: 50 + 1.5 * pt,
  cone_r0: cone-r0,
  cone_r1: cone-r1,
  cone_inner_n: Lcone.inner-n,
  cone_u_min: calc.min(..cone-us),
  cone_u_max: calc.max(..cone-us),
  cone_w0: cone-w0,
  cone_w1: cone-w1,
  tr_gap: tr-gap,
  tr_profile_mid: tr-profile-mid,
  tr_count: Ltr.trans.len(),
  tr_cross_width: tr-cross-width,
  clamp_profile_mid: (Lcl.trans.at(0).profile)(0.5),
  slv_err: slv-err,
  slv_sing: slv-sing,
  par_none: par-none,
  p1_ad: P1.ad,
  p1_quad: P1.quad,
  p1_eq: P1.eq,
  p1_tang_dc: P1.tang-dc,
  p1_tang_db: P1.tang-db,
  p1_t_dc: P1.t-dc,
  p1_t_db: P1.t-db,
  p1_y2: P1.y2,
  p1_BD: P1.BD,
  p1_r3: P1.r3,
  p2_ad: P2.ad,
  p2_quad: P2.quad,
  p2_eq: P2.eq,
  p2_tang_dc: P2.tang-dc,
  p2_tang_db: P2.tang-db,
  p2_y2: P2.y2,
  w_err: w-err,
  w_step: w-step,
  w_count: wloops.len(),
  w_pts: wvals.len(),
  head_tip_err: _dist(hp.at(2), (10, 5)),
  head_base_err: calc.abs(_dist(hp.at(0), hp.at(1)) - 2 * 0.36 * 2.6),
  head_axis_err: _dist(h-mid, (10 - 2.6, 5)),
  arc_r_err: calc.max(..arc1.map(p => calc.abs(_dist(p, (2, 3)) - 7))),
  arc_on_ray1: calc.abs(arc-e0.at(0) * 10),
  arc_on_ray2: calc.abs(-arc-el.at(1) * 10),
  arc_len_err: calc.abs(arc-steps.sum() - calc.pi * 7 / 2),
  spring_end_err: calc.max(_dist(sp.at(0), (0, 0)), _dist(sp.at(sp.len() - 1), (0, 40))),
  spring_perp_err: calc.abs(calc.max(..sp.map(p => calc.abs(p.at(0)))) - 1.8),
  spring_axial_err: calc.max(calc.abs(calc.min(..sp-ys)), calc.abs(40 - calc.max(..sp-ys))),
  lens_x_err: calc.abs(calc.max(..lo-xs) - 3.2),
  lens_y_err: calc.abs(calc.max(..lo-ys) - 10),
  lens_conc_x: calc.max(..lc-xs),
  lens_conc_xmin: calc.min(..lc-xs),
  weight_h_err: calc.abs(
    (wps.at(0).at(1).at(1) - wps.at(0).at(0).at(1))
      + (wps.at(1).at(1).at(1) - wps.at(1).at(0).at(1)) - 14,
  ),
  globe_center_err: _dist((globe-centre.x, globe-centre.y), (0, 0)),
  globe_center_visible: globe-centre.visible,
  globe_horizon_radius_err: calc.abs(
    calc.sqrt(calc.pow(globe-horizon.x, 2) + calc.pow(globe-horizon.y, 2)) - 1,
  ),
  globe_horizon_hidden: not globe-horizon.visible,
  globe_antipode_hidden: not globe-antipode.visible,
  strand_gap_err: {
    calc.abs((strand-pieces.at(1).at(0).at(0)
      - strand-pieces.at(0).at(strand-pieces.at(0).len() - 1).at(0)) - 2)
  },
  refraction_trace_points: refracted-ray.len(),
  refraction_snell_err: snell-error,
  refraction_tir_reflects_down: tir-direction.at(1) < 0,
)
#metadata(metrics) <verify>

// Hard failures make this file usable as a real regression gate.
#assert(calc.abs(calc.min(..steps) - 42 * 130deg / 1deg * calc.pi / 180 / 60) < 0.001)
#assert(calc.abs(calc.max(..steps) - 42 * 130deg / 1deg * calc.pi / 180 / 60) < 0.001)
#assert(calc.min(..radii) > 14.999999 and calc.max(..radii) < 15.000001)
#assert(calc.min(..bandradii) >= 36 - 0.25 * pt - 0.002)
#assert(calc.max(..bandradii) <= 36 + 0.25 * pt + 0.002)
#assert(calc.abs(calc.max(..ys) - (50 + 1.5 * pt)) < 1e-8)
#assert(cone-r0 == 10 and cone-r1 == 0 and cone-w1 == 0)
#assert(calc.abs(tr-gap - 2.2) < 1e-9 and tr-profile-mid > 0)
#assert(calc.abs(tr-cross-width - 12) < 1e-9 and Lcl.trans.len() > 0)
#assert(slv-err < 1e-10 and slv-sing == 1 and par-none == 1)
#assert(P1.ad < 1e-10 and P1.eq < 1e-10 and P1.tang-dc < 1e-10 and P1.tang-db < 1e-10)
#assert(P2.ad < 1e-10 and P2.eq < 1e-10 and P2.tang-dc < 1e-10 and P2.tang-db < 1e-10)
#assert(w-err < 0.1 and w-step <= calc.sqrt(1.5 * 1.5 + (40 / 27) * (40 / 27)) + 1e-9)
#assert(wloops.len() > 0)
#assert(_dist((globe-centre.x, globe-centre.y), (0, 0)) < 1e-12 and globe-centre.visible)
#assert(calc.abs(_dist((globe-horizon.x, globe-horizon.y), (0, 0)) - 1) < 1e-12)
#assert(not globe-horizon.visible and not globe-antipode.visible)
#assert(strand-pieces.len() == 2 and calc.abs((strand-pieces.at(1).at(0).at(0) - strand-pieces.at(0).at(strand-pieces.at(0).len() - 1).at(0)) - 2) < 1e-12)
#assert(refracted-ray.len() == 5 and snell-error < 1e-8)
#assert(tir-direction.at(1) < 0)

// Physics primitives: these used to be reported without failing the check.
#assert(metrics.head_tip_err < 1e-10, message: "Arrow tip moved off its endpoint")
#assert(metrics.head_base_err < 1e-10, message: "Arrowhead base width changed")
#assert(metrics.head_axis_err < 1e-10, message: "Arrowhead is off axis")
#assert(metrics.arc_r_err < 1e-10, message: "Angle mark left its circle")
#assert(metrics.arc_on_ray1 < 1e-10 and metrics.arc_on_ray2 < 1e-10,
  message: "Angle mark endpoints left their rays")
// Chord approximation is slightly shorter than a quarter-circle (0.001442 mm).
#assert(metrics.arc_len_err < 0.002, message: "Angle mark arc-length error exceeds 0.002 mm")
#assert(metrics.spring_end_err < 1e-10, message: "Spring endpoints moved")
#assert(metrics.spring_perp_err < 1e-10, message: "Spring radius changed")
#assert(metrics.spring_axial_err < 1e-10, message: "Spring extends beyond its axis endpoints")
#assert(metrics.lens_x_err < 1e-10 and metrics.lens_y_err < 1e-10,
  message: "Convex lens dimensions changed")
#assert(calc.abs(metrics.lens_conc_x - 4) < 1e-10
  and calc.abs(metrics.lens_conc_xmin + 4) < 1e-10,
  message: "Concave lens rim dimensions changed")
#assert(P1.quad < 1e-10 and P2.quad < 1e-10,
  message: "Pulley solution violates its quadratic constraint")

// Canvas primitives must not consume flow space when composed with `+`.
// An unplaced open stipple fill used to push following brush marks down.
#context {
  let extent = measure(stroke-stipple-brush(((8, 9), (16, 9)), 0.11 * pt,
    dot-size: 0.6 * pt, track-spacing: 0.9 * pt, closed: false, per: 0, seed: 4))
  assert(extent.width == 0pt and extent.height == 0pt,
    message: "Open stippled brush consumes canvas flow space")
}
