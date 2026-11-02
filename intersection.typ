// Fixed-point port of MetaPost's cubic intersection search.
// Coordinates are signed 16.16 integers; times are returned as 16.16 floats.

#let half-signed(x) = {
  if x >= 0 { int(calc.floor(x / 2)) }
  else { -int(calc.floor(-x / 2)) }
}

#let packet-from-cubic(points) = range(3).map(i => (
  points.at(i + 1).at(0) - points.at(i).at(0),
  points.at(i + 1).at(1) - points.at(i).at(1),
))

#let packet-split(packet) = {
  let left = ()
  let right = ()
  for axis in range(2) {
    let u1 = packet.at(0).at(axis)
    let u2 = packet.at(1).at(axis)
    let u3 = packet.at(2).at(axis)
    let u2-left = half-signed(u1 + u2)
    let u2-right = half-signed(u3 + u2)
    let u3-left = half-signed(u2-left + u2-right)
    left.push((u1, u2-left, u3-left))
    right.push((u3-left, u2-right, u3))
  }
  let left-packet = range(3).map(i => (left.at(0).at(i), left.at(1).at(i)))
  let right-packet = range(3).map(i => (right.at(0).at(i), right.at(1).at(i)))
  (left-packet, right-packet)
}

#let packet-bounds(packet, axis) = {
  let values = (0,)
  let position = 0
  for point in packet {
    position += point.at(axis)
    values.push(position)
  }
  (calc.min(..values), calc.max(..values))
}

#let packets-overlap(a, b, dx, dy, tolerance) = {
  let overlap = true
  for axis in range(2) {
    let delta = if axis == 0 { dx } else { dy }
    let ab = packet-bounds(a, axis)
    let bb = packet-bounds(b, axis)
    if (delta - tolerance > bb.at(1) - ab.at(0)
        or delta + tolerance < bb.at(0) - ab.at(1)) {
      overlap = false
    }
  }
  overlap
}

#let cubic-intersection(left-points, right-points, tolerance-step: 0) = {
  let a = packet-from-cubic(left-points)
  let b = packet-from-cubic(right-points)
  let start-dx = left-points.at(0).at(0) - right-points.at(0).at(0)
  let start-dy = left-points.at(0).at(1) - right-points.at(0).at(1)
  let unity = 65536
  let max-t-limit = 8 * unity
  let low-precision-limit = max-t-limit - unity / 2
  let max-t = 2
  let approximation = none
  let backtracks = 0
  let answer = none
  let stopped = false
  let stack = ((a: a, b: b, dx: start-dx, dy: start-dy,
    tolerance: 0, three-l: 0, level: 0, ai: 0, bi: 0),)

  while stack.len() > 0 and not stopped {
    let node = stack.pop()
    let overlaps = packets-overlap(node.a, node.b, node.dx, node.dy,
      node.tolerance)
    if not overlaps {
      backtracks += 1
      if backtracks > 5000 {
        if approximation != none {
          let t = int(calc.floor(approximation.at(0) / 4))
          let tt = int(calc.floor(approximation.at(1) / 4))
          while t < unity {
            t *= 2
            tt *= 2
          }
          answer = (t / unity - 1, tt / unity - 1)
        }
        stopped = true
      }
    } else {
      let current-t = calc.pow(2, node.level) + node.ai
      let current-tt = calc.pow(2, node.level) + node.bi
      if current-t >= max-t {
        if max-t == max-t-limit or max-t > low-precision-limit {
          let t = int(calc.floor(current-t / 4))
          let tt = int(calc.floor(current-tt / 4))
          answer = ((int(calc.floor((t + 1) / 2))) / unity - 1,
            (int(calc.floor((tt + 1) / 2))) / unity - 1)
          stopped = true
        } else {
          max-t *= 2
          approximation = (current-t, current-tt)
        }
      }

      if not stopped and node.level >= 19 {
        backtracks += 1
        if backtracks > 5000 {
          if approximation != none {
            let t = int(calc.floor(approximation.at(0) / 4))
            let tt = int(calc.floor(approximation.at(1) / 4))
            while t < unity {
              t *= 2
              tt *= 2
            }
            answer = (t / unity - 1, tt / unity - 1)
          }
          stopped = true
        }
      } else if not stopped {
        let a-split = packet-split(node.a)
        let b-split = packet-split(node.b)
        let next-tolerance = 2 * (node.tolerance - node.three-l
          + tolerance-step)
        let next-three-l = node.three-l + tolerance-step
        let next-dx = 2 * node.dx
        let next-dy = 2 * node.dy
        // Reverse push order gives source's LL, LR, RL, RR depth-first order.
        for order in (3, 2, 1, 0) {
          let a-side = int(calc.floor(order / 2))
          let b-side = calc.rem(order, 2)
          let a-child = if a-side == 0 { a-split.at(0) } else { a-split.at(1) }
          let b-child = if b-side == 0 { b-split.at(0) } else { b-split.at(1) }
          let a-dx = a-split.at(0).at(0).at(0) + a-split.at(0).at(1).at(0) + a-split.at(0).at(2).at(0)
          let b-dx = b-split.at(0).at(0).at(0) + b-split.at(0).at(1).at(0) + b-split.at(0).at(2).at(0)
          let a-dy = a-split.at(0).at(0).at(1) + a-split.at(0).at(1).at(1) + a-split.at(0).at(2).at(1)
          let b-dy = b-split.at(0).at(0).at(1) + b-split.at(0).at(1).at(1) + b-split.at(0).at(2).at(1)
          let dx = next-dx + if a-side == 1 { a-dx } else { 0 }
          let dx = dx - if b-side == 1 { b-dx } else { 0 }
          let dy = next-dy + if a-side == 1 { a-dy } else { 0 }
          let dy = dy - if b-side == 1 { b-dy } else { 0 }
          stack.push((a: a-child, b: b-child, dx: dx, dy: dy,
            tolerance: next-tolerance + next-three-l * (a-side + b-side),
            three-l: next-three-l, level: node.level + 1,
            ai: node.ai * 2 + a-side, bi: node.bi * 2 + b-side))
        }
      }
    }
  }
  answer
}

#let path-intersection(ray, curves) = {
  let answer = none
  for tolerance-step in (0, 3) {
    for segment in range(curves.len()) {
      if answer == none {
        let hit = cubic-intersection(ray, curves.at(segment),
          tolerance-step: tolerance-step)
        if hit != none {
          answer = (hit.at(0), segment + hit.at(1))
        }
      }
    }
    if answer != none { break }
  }
  if answer == none { (-1.0, -1.0) } else { answer }
}

#let raw-intersections(ray, curves) = {
  let direct = path-intersection(ray, curves)
  let reversed = curves.rev().map(curve => curve.rev())
  let reverse = path-intersection(ray, reversed)
  (direct, reverse)
}

#let intersection-times(ray, curves) = {
  let raw = raw-intersections(ray, curves)
  let direct = raw.at(0)
  let reverse = raw.at(1)
  if direct.at(0) < reverse.at(0) { direct }
  else if direct.at(0) < 0 { reverse }
  else { (reverse.at(0), curves.len() - reverse.at(1)) }
}
