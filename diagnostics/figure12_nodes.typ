#import "../fiziko.typ": sphere-latitude

#let (drawing, cursor, trace) = sphere-latitude(
  30,
  latitude: 45,
  samples: 360,
  seed: 15,
  with-trace: true,
  trace-latitude: 62,
)
#metadata(trace) <figure12-recursion-nodes>
