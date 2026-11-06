#import "../fiziko.typ": _flat-surface-source-width, _mp-unit

// Source row 26.80830, width-template knot 3. MetaPost records the callback
// parameter as 153:153 and returns width 34:40 in 16.16 base-256 chunks.
#let source-time = 153 / 256 + 153 / 65536
#let source-line-length = (107 + 182 / 256 + 186 / 65536) * _mp-unit
#let source-total-width = (150 + 181 / 256 + 229 / 65536) * _mp-unit
#let source-row-fraction = 155 / 256 + 192 / 65536
#let width = _flat-surface-source-width(
  source-time, source-line-length, source-total-width,
  source-row-fraction, 1, 2)
#metadata((time-fixed: int(calc.round(source-time * 65536)),
  width-fixed: int(calc.round(width / _mp-unit * 65536))))
  <s104-width-sample>
