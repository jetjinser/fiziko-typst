// Fixed-point hit parameters for the synthetic S104 hatch panel.
#import "../fiziko.typ": _scanline-segments, _source-max-shading

#let panel = ((8, 8), (56, 13), (50, 36), (5, 31))
#metadata(_scanline-segments(
  panel, -30, 3 * _source-max-shading,
  fit: true, source-fixed: true,
)) <s104-fixed-scanline-hits>
