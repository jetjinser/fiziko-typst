// Per-landmass source-topology probe for the pinned M11 comparison fixture.
#import "../fiziko.typ": _globe-visible-paths
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let details = ()
#for (i, land) in upstream-landmasses.enumerate() {
  let paths = _globe-visible-paths(land, (0, 0), 15, (19, 22))
  details.push((landmass: i + 1, input-points: land.len(),
    visible-runs: paths.len(), run-lengths: paths.map(path => path.len())))
}
#metadata((landmasses: details,
  total-runs: details.map(x => x.at("visible-runs")).sum())) <m11-coast-geometry>
