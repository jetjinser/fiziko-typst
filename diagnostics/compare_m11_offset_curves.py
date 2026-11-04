#!/usr/bin/env python3
"""Replay MetaPost offsetPathGenerate and compare M11 boundary cubics.

Usage: compare_m11_offset_curves.py MPOST_TRACE_LOG

The numerical arc integral is Simpson's rule. Source coordinates and control
points are read from the instrumented MetaPost 2.11 trace in millimetres.
"""

import argparse
import math
from collections import defaultdict
from pathlib import Path


def read_trace(path):
    points = defaultdict(dict)
    offsets = defaultdict(dict)
    output = defaultdict(lambda: defaultdict(dict))
    for line in path.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        tag = fields[0]
        if tag == "M11INPUTA":
            call, index = int(fields[1]), int(fields[2])
            points[call][index] = [
                (float(fields[3]), float(fields[4])),
                (float(fields[5]), float(fields[6])),
            ]
        elif tag == "M11INPUTB":
            call, index = int(fields[1]), int(fields[2])
            points[call][index].extend([
                (float(fields[3]), float(fields[4])),
                (float(fields[5]), float(fields[6])),
            ])
        elif tag == "M11OFFSET":
            call, index = int(fields[1]), int(fields[2])
            offsets[call][index] = (float(fields[3]), float(fields[4]))
        elif tag in ("M11EDGECURVEA", "M11EDGECURVEB"):
            # q2/q3 logging happens just after traceBoundaryCall increments.
            call = int(fields[1]) - 1
            curve, side = int(fields[2]), int(fields[3])
            controls = [
                (float(fields[4]), float(fields[5])),
                (float(fields[6]), float(fields[7])),
            ]
            if tag == "M11EDGECURVEA":
                output[call][side][curve] = controls
            else:
                output[call][side][curve].extend(controls)
    return points, offsets, output


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def mul(a, scalar):
    return (a[0] * scalar, a[1] * scalar)


def unit(a):
    length = math.hypot(*a)
    return (a[0] / length, a[1] / length) if length else (0.0, 0.0)


def rotate(a, degrees):
    angle = math.radians(degrees)
    return (a[0] * math.cos(angle) - a[1] * math.sin(angle),
            a[0] * math.sin(angle) + a[1] * math.cos(angle))


def angle(a):
    return math.degrees(math.atan2(a[1], a[0]))


def derivative(curve, t):
    u = 1 - t
    return tuple(
        3 * u * u * (curve[1][axis] - curve[0][axis])
        + 6 * u * t * (curve[2][axis] - curve[1][axis])
        + 3 * t * t * (curve[3][axis] - curve[2][axis])
        for axis in (0, 1)
    )


def arc_length(curves, start, end):
    """Integrate cubic speed over a path-time interval."""
    total = 0.0
    while start < end - 1e-12:
        index = int(math.floor(start))
        lo = start - index
        hi = min(1.0, end - index)
        if index >= len(curves):
            break
        steps = 128
        step = (hi - lo) / steps
        speeds = [math.hypot(*derivative(curves[index], lo + j * step))
                  for j in range(steps + 1)]
        total += step / 3 * (
            speeds[0] + speeds[-1]
            + 4 * sum(speeds[1:-1:2])
            + 2 * sum(speeds[2:-1:2])
        )
        start = index + hi
    return total


def segment_intersection(a, b, c, d):
    ab = sub(b, a)
    cd = sub(d, c)
    denominator = ab[0] * cd[1] - ab[1] * cd[0]
    if abs(denominator) < 1e-15:
        return None
    ca = sub(c, a)
    t = (ca[0] * cd[1] - ca[1] * cd[0]) / denominator
    u = (ca[0] * ab[1] - ca[1] * ab[0]) / denominator
    return t, u, add(a, mul(ab, t))


def offset_path(curves, radii):
    """Port offsetPathGenerate for the constant-width M11 tube outline."""
    count = len(curves)
    joins = []
    for index in range(count + 1):
        point = curves[index][0] if index < count else curves[-1][3]
        incoming = curves[index - 1][2] if index > 0 else point
        outgoing = curves[index][1] if index < count else point
        if math.dist(incoming, point) == 0:
            incoming = add(point, sub(point, outgoing))
        if math.dist(outgoing, point) == 0:
            outgoing = add(point, sub(point, incoming))

        in_normal = rotate(unit(sub(incoming, point)), -90)
        out_normal = rotate(unit(sub(point, outgoing)), -90)
        local_length = arc_length(curves, max(0.0, index - 0.5),
                                  min(float(count), index + 0.5))
        radius = radii[index]
        line1 = (
            add(add(point, mul(in_normal, radius)),
                mul(unit(sub(point, incoming)), local_length)),
            add(add(point, mul(in_normal, radius)),
                mul(unit(sub(incoming, point)), local_length)),
        )
        line2 = (
            add(add(point, mul(out_normal, radius)),
                mul(unit(sub(point, outgoing)), local_length)),
            add(add(point, mul(out_normal, radius)),
                mul(unit(sub(outgoing, point)), local_length)),
        )
        hit = segment_intersection(*line1, *line2)
        if (abs(angle(in_normal) - angle(out_normal)) > 2
                and hit is not None
                and 0 < hit[0] <= 1
                and -1e-8 <= hit[1] <= 1 + 1e-8):
            joins.append(hit[2])
        else:
            joins.append(add(point, mul(in_normal, radius)))

    result = []
    for index, curve in enumerate(curves):
        p0, p1, p2, p3 = curve
        start = joins[index]
        endpoint_normal = rotate(unit(sub(p3, p2)), 90)
        local_endpoint = add(p3, mul(endpoint_normal, radii[index + 1]))
        scale = math.dist(start, local_endpoint) / max(1e-15, math.dist(p0, p3))
        control1 = add(start, mul(sub(p1, p0), scale))
        control2 = add(local_endpoint, mul(sub(p2, p3), scale))
        result.append((start, control1, control2, joins[index + 1]))
    return result


def compare(path):
    points, offsets, output = read_trace(path)
    compared = 0
    for call in sorted(set(points) & set(offsets) & set(output)):
        curves = [points[call][i] for i in sorted(points[call])]
        offset_points = [offsets[call][i] for i in sorted(offsets[call])]
        if not curves or len(curves) != len(offset_points) - 1:
            raise ValueError(f"call {call}: incomplete center or offset trace")
        widths = [point[1] for point in offset_points]
        if max(widths) - min(widths) > 1e-8:
            raise ValueError(f"call {call}: diagnostic only supports constant offset width")
        if not all(len(curve) == 4 for curve in curves):
            raise ValueError(f"call {call}: incomplete cubic controls")
        for side in (2, 3):
            radii = [point[1] * (1 if side == 2 else -1)
                     for point in offset_points]
            candidate = offset_path(curves, radii)
            expected = [output[call][side][i]
                        for i in sorted(output[call][side])]
            if len(expected) != len(candidate):
                raise ValueError(f"call {call} side {side}: control count mismatch")
            errors = [math.dist(a, b)
                      for actual, source in zip(candidate, expected)
                      for a, b in zip(actual, source)]
            compared += len(errors)
            print(f"call={call} side={side} segments={len(candidate)} "
                  f"controls={len(errors)} mean={sum(errors)/len(errors):.8g} "
                  f"max={max(errors):.8g} mm")
    if compared == 0:
        raise ValueError("trace contains no paired source offset curves")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    compare(parser.parse_args().source_trace)
