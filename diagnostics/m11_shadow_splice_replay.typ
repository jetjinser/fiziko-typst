// Replay all source-traced M11 shadowCut path-time interval splices.
#import "../fiziko.typ": _source-path-time-at, _source-path-time-splice
#import "../build/m11-shadow-splice-cases.typ": m11-shadow-cases

#let source-path(length) = range(length).map(i => (float(i), float(i + 1)))
#let cut-checks = 0
#let matched-cuts = 0
#let terminal-checks = 0
#let matched-terminals = 0
#for case in m11-shadow-cases {
  let segments = source-path(case.initial)
  for splice in case.splices {
    segments = _source-path-time-splice(segments, splice.time)
    cut-checks += 1
    if segments.len() == splice.length { matched-cuts += 1 }
  }
  terminal-checks += 1
  if segments.len() == case.terminal { matched-terminals += 1 }
}

#let call4-lane2 = m11-shadow-cases.find(case => case.call == 4 and case.lane == 2)
#let call4-lane2-first = _source-path-time-splice(
  source-path(call4-lane2.initial), call4-lane2.splices.first().time)
#let recovered-time = _source-path-time-at(
  call4-lane2-first, call4-lane2.splices.at(1).time)
#let replay = (
  cut-checks: cut-checks,
  matched-cuts: matched-cuts,
  terminal-checks: terminal-checks,
  matched-terminals: matched-terminals,
  call4-lane2-recovered-time: recovered-time,
)
#metadata(replay) <m11-shadow-splice-replay>
