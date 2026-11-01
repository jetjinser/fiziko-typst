#import "../fiziko.typ": _metapost-rng-sequence

#let expected = (
  0.25172, 0.39517, 0.25339, 0.06187,
  0.98349, 0.37555, 0.82700, 0.54059,
  0.09328, 0.03542, 0.12355, 0.22124,
  0.25888, 0.27946, 0.02524, 0.21217,
)
#let actual = _metapost-rng-sequence(1, expected.len())
#for (index, value) in expected.enumerate() {
  assert(calc.abs(actual.at(index) - value) < 0.000005,
    message: "MetaPost RNG vector mismatch at index " + str(index))
}
MetaPost scaled RNG vectors match.
