#import "../fiziko.typ": *
#let a = sphere-latitude(20, latitude: -60, samples: 360, with-trace: true)
#let b = sphere-latitude(30, latitude: 45, samples: 360, rng-offset: a.at(1), with-trace: true)
#metadata((a.at(2), b.at(2))) <traces>
