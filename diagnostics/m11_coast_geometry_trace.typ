// Per-landmass source-topology probe for the pinned M11 comparison fixture.
#import "../fiziko.typ": _globe-land-outline-data, _globe-visible-paths, globe-project
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let details = ()
#let arc-details = ()
#for (i, land) in upstream-landmasses.enumerate() {
  let paths = _globe-visible-paths(land, (0, 0), 15, (19, 22))
  let data = _globe-land-outline-data(land, (0, 0), 15, (19, 22))
  let first = globe-project(land.first().at(0), land.first().at(1),
    rotation: (0, 0))
  details.push((landmass: i + 1, input-points: land.len(),
    visible-runs: paths.len(), run-lengths: paths.map(path => path.len()),
    points: paths.map(path => path.map(p => (x: p.at(0), y: p.at(1)))),
    first-visible: first.visible,
    first-projected: if first.visible {
      (19 + 15 * first.x, 22 - 15 * first.y)
    } else { none }))
  if data != none {
    arc-details.push((landmass: i + 1, outline-runs: data.runs.len(),
      outline-run-lengths: data.runs.map(run => run.len()),
      coast-time-segments: data.runs.map(run => run.len() - 1),
      arcs: data.arcs,
      arc-time-segments: data.arcs.map(arc => if arc == none { 0 } else {
        let from = arc.at(0)
        let to = arc.at(1)
        let boundaries = 1
        if to > from {
          let boundary = calc.floor(from) + 1
          while boundary < to { boundaries += 1; boundary += 1 }
        } else {
          let boundary = calc.ceil(from) - 1
          while boundary > to { boundaries += 1; boundary -= 1 }
        }
        boundaries
      }),
      outline-start: data.points.first(),
      outline-points: data.points.map(p => (x: p.at(0), y: p.at(1))),
      source-times: data.source-times,
      source-time-end: data.source-time-end,
      endpoints: data.runs.map(run => (first: run.first(), last: run.last()))))
  }
}
#metadata((landmasses: details,
  total-runs: details.map(x => x.at("visible-runs")).sum(),
  outline-arcs: arc-details)) <m11-coast-geometry>
