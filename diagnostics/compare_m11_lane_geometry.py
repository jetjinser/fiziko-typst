#!/usr/bin/env python3
"""Pair source pre-shadow cubic lanes with sampled Typst knot tube lanes."""

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path


def bezier(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


def point_segment_distance(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dy * dy
    if denom == 0:
        return math.dist(p, a)
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / denom))
    return math.dist(p, (a[0] + t * dx, a[1] + t * dy))


def distance_to_polyline(p, points):
    return min(point_segment_distance(p, a, b) for a, b in zip(points, points[1:]))


def source_lanes(path):
    controls = defaultdict(dict)
    for line in path.read_text().splitlines():
        f = line.split()
        if not f:
            continue
        if f[0] == "M11CURVEA":
            key, i = (int(f[1]), int(f[2])), int(f[3])
            controls[key][i] = [(float(f[4]), float(f[5])), (float(f[6]), float(f[7]))]
        elif f[0] == "M11CURVEB":
            key, i = (int(f[1]), int(f[2])), int(f[3])
            controls[key][i] += [(float(f[4]), float(f[5])), (float(f[6]), float(f[7]))]
    return {key: [controls[key][i] for i in sorted(controls[key])]
            for key in controls if controls[key] and all(len(v) == 4 for v in controls[key].values())}


def typst_lanes(path):
    traces = json.loads(path.read_text())
    lanes = []
    for trace in traces:
        for lane in trace["inner-lanes"]:
            points = [tuple(map(float, p)) for p in lane["points"]]
            lanes.append((trace["strand"], trace["segment"], lane["lane"], points))
    return lanes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("typst_trace", type=Path)
    args = parser.parse_args()
    sources = source_lanes(args.source_trace)
    typst = typst_lanes(args.typst_trace)
    for key, cubics in sorted(sources.items()):
        samples = [bezier(cubic, step / 16) for cubic in cubics for step in range(16)]
        samples.append(cubics[-1][-1])
        distances = []
        for strand, segment, lane, points in typst:
            mean = sum(distance_to_polyline(p, points) for p in samples) / len(samples)
            distances.append((mean, strand, segment, lane))
        best = sorted(distances)[:3]
        summary = ", ".join(
            f"strand={s}/segment={i}/lane={lane}:{d:.6f}mm" for d, s, i, lane in best)
        print(f"source call={key[0]} lane={key[1]} cubics={len(cubics)} -> {summary}")


if __name__ == "__main__":
    main()
