// Invoke the production globe path so the embedded metadata captures its exact
// coast widths, recursive nodes, and per-landmass dash RNG use.
#import "../fiziko.typ": globe
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#globe(30, rotation: (0, 0), lands: upstream-landmasses,
  shading: "latitude", coast-step: 0, center: (19, 22),
  _trace-coasts: true)
