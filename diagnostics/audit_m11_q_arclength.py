#!/usr/bin/env python3
"""Compare source M11 q-template x knots with traced post-shadow cubic arc."""

import math
import sys
import argparse
from collections import defaultdict
from pathlib import Path


FIXED = 65536
# MetaPost's internal fraction is 28-bit fixed point. The arc estimator's
# stopping threshold is unity / 4096 (mpmath.w: arc_tol_k).
FRACTION_ONE = 1 << 28
ARC_TOLERANCE = FRACTION_ONE // 4096


def fixed_pair(hi, lo):
    return int(hi) * 256 + int(lo)


def fixed_coordinate(whole, hi, lo):
    return int(whole) + int(hi) / 256 + int(lo) / FIXED


def simpson_speed(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    dx = 3 * u * u * (p1[0] - p0[0]) + 6 * u * t * (p2[0] - p1[0]) + 3 * t * t * (p3[0] - p2[0])
    dy = 3 * u * u * (p1[1] - p0[1]) + 6 * u * t * (p2[1] - p1[1]) + 3 * t * t * (p3[1] - p2[1])
    return math.hypot(dx, dy)


def integrate(points, a, b, fa, fm, fb, whole, tolerance, depth):
    middle = (a + b) / 2
    left_middle = (a + middle) / 2
    right_middle = (middle + b) / 2
    flm = simpson_speed(points, left_middle)
    frm = simpson_speed(points, right_middle)
    left = (middle - a) * (fa + 4 * flm + fm) / 6
    right = (b - middle) * (fm + 4 * frm + fb) / 6
    delta = left + right - whole
    if depth <= 0 or abs(delta) <= 15 * tolerance:
        return left + right + delta / 15
    return integrate(points, a, middle, fa, flm, fm, left, tolerance / 2, depth - 1) + integrate(
        points, middle, b, fm, frm, fb, right, tolerance / 2, depth - 1
    )


def arc_length(points):
    fa = simpson_speed(points, 0)
    fm = simpson_speed(points, 0.5)
    fb = simpson_speed(points, 1)
    whole = (fa + 4 * fm + fb) / 6
    return integrate(points, 0, 1, fa, fm, fb, whole, 1e-12, 24)


def half_trunc(value):
    return (abs(value) // 2) * (-1 if value < 0 else 1)


def round_ratio(numerator, denominator):
    sign = -1 if (numerator < 0) != (denominator < 0) else 1
    numerator, denominator = abs(numerator), abs(denominator)
    return sign * ((numerator + denominator // 2) // denominator)


def pyth_add(a, b):
    """Fixed-point port of MetaPost's scaled Euclidean norm (pyth_add)."""
    a, b = abs(a), abs(b)
    if a < b:
        a, b = b, a
    if b == 0:
        return a
    if a >= 2 * FRACTION_ONE:
        a //= 4
        b //= 4
        big = True
    else:
        big = False
    while True:
        ratio = round_ratio(b * FRACTION_ONE, a)
        ratio = round_ratio(ratio * ratio, FRACTION_ONE)
        if ratio == 0:
            break
        ratio = round_ratio(ratio * FRACTION_ONE, 4 * FRACTION_ONE + ratio)
        a += round_ratio((a + a) * ratio, FRACTION_ONE)
        b = round_ratio(b * ratio, FRACTION_ONE)
    return a * 4 if big else a


def metapost_arc_test(d0, d1, d2, v0=None, v02=None, v2=None,
                      tolerance=ARC_TOLERANCE, depth=0):
    """MetaPost's recursive adaptive arc test on cubic derivative controls."""
    if depth > 40:
        raise RecursionError("MetaPost arc-test subdivision exceeded 40 levels")
    v0 = pyth_add(*d0) if v0 is None else v0
    v2 = pyth_add(*d2) if v2 is None else v2
    dx01 = tuple(half_trunc(d0[i] + d1[i]) for i in (0, 1))
    dx12 = tuple(half_trunc(d1[i] + d2[i]) for i in (0, 1))
    dx02 = tuple(half_trunc(dx01[i] + dx12[i]) for i in (0, 1))
    v002 = pyth_add(half_trunc(d0[0] + dx02[0]) + dx01[0],
                    half_trunc(d0[1] + dx02[1]) + dx01[1])
    v022 = pyth_add(half_trunc(dx02[0] + d2[0]) + dx12[0],
                    half_trunc(dx02[1] + d2[1]) + dx12[1])
    if v02 is None:
        v02 = pyth_add(half_trunc(d0[0] + d2[0]) + d1[0],
                       half_trunc(d0[1] + d2[1]) + d1[1])
    tmp = (v02 + 2) >> 1
    arc1 = (((v0 + tmp) >> 1) - v002)
    arc1 = half_trunc(arc1) + v002
    arc = (((v2 + tmp) >> 1) - v022)
    arc = half_trunc(arc) + v022
    arc += arc1
    simple_x = all(x >= 0 for x in (d0[0], d1[0], d2[0])) or all(
        x <= 0 for x in (d0[0], d1[0], d2[0]))
    simple_y = all(y >= 0 for y in (d0[1], d1[1], d2[1])) or all(
        y <= 0 for y in (d0[1], d1[1], d2[1]))
    simple = simple_x and simple_y
    if not simple:
        direct = all(x >= y for x, y in zip((d0[0], d1[0], d2[0]),
                                             (d0[1], d1[1], d2[1]))) or all(
            x <= y for x, y in zip((d0[0], d1[0], d2[0]),
                                    (d0[1], d1[1], d2[1])))
        if direct:
            negated = tuple(-x for x in (d0[0], d1[0], d2[0]))
            simple = all(x >= y for x, y in zip(negated,
                                                 (d0[1], d1[1], d2[1]))) or all(
                x <= y for x, y in zip(negated, (d0[1], d1[1], d2[1])))
    discrepancy = abs(arc - ((v0 + v2) >> 1) - v02)
    if simple and discrepancy <= tolerance:
        return arc
    next_tolerance = tolerance + (tolerance >> 1)
    half_v02 = v02 >> 1
    left = metapost_arc_test(d0, dx01, dx02, v0, v002, half_v02,
                             next_tolerance, depth + 1)
    right = metapost_arc_test(dx02, dx12, d2, half_v02, v022, v2,
                              next_tolerance, depth + 1)
    return half_trunc(right - left) + left


def metapost_arc_length_fixed(points):
    d0 = tuple(points[1][axis] - points[0][axis] for axis in (0, 1))
    d1 = tuple(points[2][axis] - points[1][axis] for axis in (0, 1))
    d2 = tuple(points[3][axis] - points[2][axis] for axis in (0, 1))
    return metapost_arc_test(d0, d1, d2)


def reconstruct_from_quarters(points):
    """Mirror the tube's p0/p25/p75/p3 cubic reconstruction in 16.16."""
    sampled = [tuple(int(round(x * FIXED)) for x in bezier(points, t))
               for t in (0, 0.25, 0.75, 1)]
    p0, p25, p75, p3 = sampled
    controls = [p0]
    p1, p2 = [], []
    for axis in (0, 1):
        a = 64 * p25[axis] - 27 * p0[axis] - p3[axis]
        b = 64 * p75[axis] - p0[axis] - 27 * p3[axis]
        p1.append(round_ratio(3 * a - b, 72))
        p2.append(round_ratio(-a + 3 * b, 72))
    controls.extend((tuple(p1), tuple(p2), p3))
    return controls


def read_trace(path):
    curves = defaultdict(dict)
    qcurves = defaultdict(lambda: defaultdict(dict))
    source_arcs = {}
    for line in path.read_text().splitlines():
        f = line.split()
        if not f:
            continue
        if f[0] == "M11POSTFIX":
            key = (int(f[1]), int(f[2]), int(f[3]))
            control = int(f[4])
            curves[key][control] = (
                fixed_coordinate(f[5], f[6], f[7]),
                fixed_coordinate(f[8], f[9], f[10]),
            )
        elif f[0] == "M11BQPT" and int(f[3]) == 0:
            call, lane, _, segment, control = map(int, f[1:6])
            qcurves[(call, lane)][segment][control] = (
                fixed_pair(f[6], f[7]), fixed_pair(f[8], f[9])
            )
        elif f[0] == "M11POSTARC":
            key = (int(f[1]), int(f[2]), int(f[3]))
            source_arcs[key] = fixed_pair(f[4], f[5]) * 256 + int(f[6])
    return curves, qcurves, source_arcs


def typst_fixture(path, output):
    curves, qcurves, source_arcs = read_trace(path)
    lines = ["// Generated from the pinned M11 MetaPost trace by audit_m11_q_arclength.py.",
             "#let m11-fixed-arc-fixture = ("]
    for key, qpath in sorted(qcurves.items()):
        parts = []
        previous = 0
        for index in sorted(qpath):
            points = curves[(key[0], key[1], index)]
            if sorted(points) != [0, 1, 2, 3]:
                raise ValueError(f"incomplete controls for {key} segment {index}")
            current = source_arcs[(key[0], key[1], index)]
            arc = current - previous
            previous = current
            fixed = [tuple(int(round(axis * FIXED)) for axis in points[i])
                     for i in range(4)]
            reconstructed = reconstruct_from_quarters([points[i] for i in range(4)])
            point_text = ", ".join(
                f"({p[0]} / 65536, {p[1]} / 65536)" for p in fixed)
            reconstructed_text = ", ".join(
                f"({p[0]} / 65536, {p[1]} / 65536)" for p in reconstructed)
            parts.append(f"(points: ({point_text}), reconstructed: ({reconstructed_text}), expected: {arc})")
        items = ",\n    ".join(parts)
        lines.append(f"  (call: {key[0]}, lane: {key[1]}, segments: (\n    {items}\n  )),")
    lines.extend([")", ""])
    output.write_text("\n".join(lines))


def audit(path):
    curves, qcurves, source_arcs = read_trace(path)
    reports = []
    for key, qpath in sorted(qcurves.items()):
        curve_ids = sorted(index for call, lane, index in curves if (call, lane) == key)
        if curve_ids != list(range(len(curve_ids))):
            raise ValueError(f"non-contiguous traced center cubics for {key}: {curve_ids}")
        if sorted(qpath) != curve_ids:
            raise ValueError(f"q/center segment mismatch for {key}: {len(qpath)} vs {len(curve_ids)}")
        cumulative = 0.0
        arc_errors = []
        source_arc_errors = []
        port_arc_errors = []
        reconstructed_arc_errors = []
        sampled_arc_errors = {steps: [] for steps in (1, 4, 8, 16, 32)}
        control_errors = []
        for index in curve_ids:
            c = curves[(key[0], key[1], index)]
            if sorted(c) != [0, 1, 2, 3] or sorted(qpath[index]) != [0, 1, 2, 3]:
                raise ValueError(f"incomplete control points for {key} segment {index}")
            q = qpath[index]
            cumulative += arc_length([c[i] for i in range(4)])
            arc_errors.append(abs(q[3][0] - cumulative * FIXED))
            if (key[0], key[1], index) not in source_arcs:
                raise ValueError(f"missing source arclength for {key} segment {index}")
            source_arc = source_arcs[(key[0], key[1], index)]
            source_arc_errors.append(abs(q[3][0] - source_arc))
            fixed_points = [
                tuple(int(round(c[point][axis] * FIXED)) for axis in (0, 1))
                for point in range(4)
            ]
            port_arc = metapost_arc_length_fixed(fixed_points)
            if index == 0:
                port_prefix = 0
            else:
                port_prefix = source_arc_total
            source_arc_total = port_prefix + port_arc
            port_arc_errors.append(abs(source_arc - source_arc_total))
            source_arc_start = source_arcs[(key[0], key[1], index - 1)] if index > 0 else 0
            source_arc_segment = source_arc - source_arc_start
            reconstructed_arc = metapost_arc_length_fixed(reconstruct_from_quarters(
                [c[i] for i in range(4)]))
            reconstructed_arc_errors.append(abs(source_arc_segment - reconstructed_arc))
            for steps in sampled_arc_errors:
                points = [bezier([c[i] for i in range(4)], j / steps)
                          for j in range(steps + 1)]
                cumulative_sampled = sum(math.dist(a, b)
                                         for a, b in zip(points, points[1:]))
                # Recompute the prefix because each trace value is cumulative.
                if index == 0:
                    prefix = 0.0
                else:
                    prefix = sampled_arc_errors[steps][-1][1]
                estimate = prefix + cumulative_sampled * FIXED
                sampled_arc_errors[steps].append(
                    (abs(source_arc - estimate), estimate)
                )
            for axis in range(2):
                start, end = q[0][axis], q[3][axis]
                # Nearest 16.16 unit for the `--` one-third/two-third controls.
                expected = (start + round((end - start) / 3),
                            start + round(2 * (end - start) / 3))
                control_errors.extend((abs(q[1][axis] - expected[0]),
                                       abs(q[2][axis] - expected[1])))
        reports.append((key, len(arc_errors), max(arc_errors), sum(arc_errors) / len(arc_errors),
                        max(control_errors, default=0), max(source_arc_errors),
                        sum(source_arc_errors) / len(source_arc_errors), sampled_arc_errors,
                        max(port_arc_errors), sum(port_arc_errors) / len(port_arc_errors),
                        max(reconstructed_arc_errors),
                        sum(reconstructed_arc_errors) / len(reconstructed_arc_errors)))
    if not reports:
        raise SystemExit("no M11 root q templates or exact post-shadow controls found")
    print("call lane segments max-arc-error mean-arc-error max-line-control-error (16.16 bp units)")
    for row in reports:
        key, count, maximum, mean, control, source_max, source_mean, _, port_max, port_mean, recon_max, recon_mean = row
        print(f"{key[0]} {key[1]} {count} {maximum:.3f} {mean:.3f} {control} "
              f"source-arclength-q-error={source_max}/{source_mean:.3f} "
              f"ported-arc-error={port_max}/{port_mean:.3f} "
              f"quarter-reconstructed-arc-error={recon_max}/{recon_mean:.3f}")
    weighted_mean = sum(row[3] * row[1] for row in reports) / sum(row[1] for row in reports)
    print(f"aggregate quadrature/q error: {max(row[2] for row in reports):.3f}/{weighted_mean:.3f} units")
    print(f"aggregate max source-arc/q mismatch: {max(row[5] for row in reports)} units")
    print(f"aggregate max/mean ported arc error: {max(row[8] for row in reports)}/"
          f"{sum(row[9]*row[1] for row in reports)/sum(row[1] for row in reports):.3f} units")
    print(f"aggregate max/mean quarter-reconstructed arc error: {max(row[10] for row in reports)}/"
          f"{sum(row[11]*row[1] for row in reports)/sum(row[1] for row in reports):.3f} units")
    for steps in (1, 4, 8, 16, 32):
        vals = [err for row in reports for err, _ in row[7][steps]]
        print(f"polyline samples/cubic={steps}: max/mean source-arc error "
              f"{max(vals):.3f}/{sum(vals)/len(vals):.3f} units")
    print(f"aggregate max q-control deviation from linear thirds: {max(row[4] for row in reports)} units")


def bezier(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("trace", type=Path)
    parser.add_argument("--typst-fixture", type=Path)
    args = parser.parse_args()
    audit(args.trace)
    if args.typst_fixture:
        typst_fixture(args.trace, args.typst_fixture)
