// Random-call totals for M11's two masked latitude layers.
#import "../fiziko.typ": _globe-land-mask, _source-max-shading, _source-spacing, sphere-latitude
#import "../comparisons/globe-coasts.typ": upstream-landmasses

#let center = (19, 22)
#let rotation = (0, 0)
#let is-land = _globe-land-mask(upstream-landmasses)
#let ocean = sphere-latitude(30, latitude: 0,
  spacing: _source-spacing, max-w: 0.85 * _source-max-shading,
  gamma: 0, center: center, outline: false,
  seed: 1, rng: "metapost",
  surface-mask: (lon, lat) => not is-land(lon, lat),
  mask-rotation: rotation, with-rng: true)
#let land = sphere-latitude(30, latitude: 0,
  spacing: _source-spacing, max-w: 1.28 * _source-max-shading,
  gamma: 0, center: center, outline: false,
  seed: 1, rng: "metapost", rng-offset: ocean.at(1),
  surface-mask: is-land, mask-rotation: rotation, with-rng: true)
#let ocean-full = sphere-latitude(30, latitude: 0,
  spacing: _source-spacing, max-w: 0.85 * _source-max-shading,
  gamma: 0, center: center, outline: false,
  seed: 1, rng: "metapost", with-rng: true)
#let land-full = sphere-latitude(30, latitude: 0,
  spacing: _source-spacing, max-w: 1.28 * _source-max-shading,
  gamma: 0, center: center, outline: false,
  seed: 1, rng: "metapost", rng-offset: ocean-full.at(1),
  with-rng: true)
#metadata((masked-ocean: ocean.at(1), masked-land: land.at(1),
  full-ocean: ocean-full.at(1), full-land: land-full.at(1))) <m11-coast-rng>
