// Per-landmass source-topology probe for the pinned M11 comparison fixture.
#import "../fiziko.typ": _globe-land-outline-data, _globe-visible-paths
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let details = ()
#let arc-details = ()
#for (i, land) in upstream-landmasses.enumerate() {
  let paths = _globe-visible-paths(land, (0, 0), 15, (19, 22))
  let data = _globe-land-outline-data(land, (0, 0), 15, (19, 22))
  details.push((landmass: i + 1, input-points: land.len(),
    visible-runs: paths.len(), run-lengths: paths.map(path => path.len()),
    points: paths.map(path => path.map(p => (x: p.at(0), y: p.at(1))))))
  if data != none {
    arc-details.push((landmass: i + 1, outline-runs: data.runs.len(),
      arcs: data.arcs,
      endpoints: data.runs.map(run => (first: run.first(), last: run.last()))))
  }
}
#metadata((landmasses: details,
  total-runs: details.map(x => x.at("visible-runs")).sum(),
  outline-arcs: arc-details)) <m11-coast-geometry>
