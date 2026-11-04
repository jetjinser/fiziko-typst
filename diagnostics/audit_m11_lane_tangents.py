#!/usr/bin/env python3
"""Compare traced M11 source lane tangents with their paired Typst dense lanes."""

import json
import math
import sys
from collections import defaultdict
from pathlib import Path


PAIRS = {
    (4, 2): (1, 0, 5),
    (4, 6): (1, 0, 1),
    (5, 2): (1, 2, 5),
}


def bezier(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    return tuple(u**3 * a + 3 * u*u*t * b + 3 * u*t*t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


def tangent(points, t):
    p0, p1, p2, p3 = points
    u = 1 - t
    vector = tuple(3 * u*u * (b - a) + 6*u*t * (c - b)
                   + 3*t*t * (d - c)
                   for a, b, c, d in zip(p0, p1, p2, p3))
    length = math.hypot(*vector)
    return tuple(v / length for v in vector) if length else (0.0, 0.0)


def closest_segment(point, path):
    best = None
    for a, b in zip(path, path[1:]):
        delta = (b[0] - a[0], b[1] - a[1])
        length2 = delta[0]**2 + delta[1]**2
        if length2 == 0:
            continue
        offset = (point[0] - a[0], point[1] - a[1])
        fraction = max(0.0, min(1.0,
            (offset[0]*delta[0] + offset[1]*delta[1]) / length2))
        projected = (a[0] + fraction*delta[0], a[1] + fraction*delta[1])
        distance = math.dist(point, projected)
        length = math.sqrt(length2)
        direction = (delta[0] / length, delta[1] / length)
        if best is None or distance < best[0]:
            best = distance, direction
    return best


def source_lanes(path):
    controls = defaultdict(dict)
    for line in path.read_text().splitlines():
        f = line.split()
        if f and f[0] in ("M11CURVEA", "M11CURVEB"):
            key, index = (int(f[1]), int(f[2])), int(f[3])
            pair = [(float(f[4]), float(f[5])), (float(f[6]), float(f[7]))]
            if f[0] == "M11CURVEA":
                controls[key][index] = pair
            else:
                controls[key][index].extend(pair)
    return {key: [value[i] for i in sorted(value)]
            for key, value in controls.items() if all(len(c) == 4 for c in value.values())}


def typst_lane(path, key):
    strand, segment, lane_index = PAIRS[key]
    traces = json.loads(path.read_text())
    for trace in traces:
        if (trace["strand"], trace["segment"]) != (strand, segment):
            continue
        for lane in trace["inner-lanes"]:
            if lane["lane"] == lane_index:
                field = "dense-points" if "dense-points" in lane else "points"
                return [tuple(map(float, p)) for p in lane[field]]
    raise ValueError(f"missing Typst lane for source call/lane {key}")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("audit_m11_lane_tangents.py SOURCE_TRACE TYPST_TRACE_JSON")
    sources = source_lanes(Path(sys.argv[1]))
    for key, mapping in PAIRS.items():
        curves = sources[key]
        path = typst_lane(Path(sys.argv[2]), key)
        distances = []
        angle_errors = []
        by_curve = []
        for curve_index, curve in enumerate(curves):
            local_distances, local_angles = [], []
            for sample_index in range(16):
                t = sample_index / 16
                source_point = bezier(curve, t)
                source_tangent = tangent(curve, t)
                distance, candidate_tangent = closest_segment(source_point, path)
                dot = max(-1.0, min(1.0,
                    source_tangent[0] * candidate_tangent[0]
                    + source_tangent[1] * candidate_tangent[1]))
                local_distances.append(distance)
                local_angles.append(math.degrees(math.acos(dot)))
            distances.extend(local_distances)
            angle_errors.extend(local_angles)
            by_curve.append((sum(local_angles) / len(local_angles),
                             max(local_angles),
                             sum(local_distances) / len(local_distances),
                             curve_index))
        worst = sorted(by_curve, reverse=True)[:5]
        print(f"call/lane={key[0]}/{key[1]} mapped={mapping} "
              f"mean/max-distance={sum(distances)/len(distances):.7f}/"
              f"{max(distances):.7f}mm mean/max-tangent="
              f"{sum(angle_errors)/len(angle_errors):.4f}/"
              f"{max(angle_errors):.4f}deg")
        print("  worst source cubic (index: mean/max angle, mean distance): "
              + ", ".join(f"{i}:{mean:.3f}/{maximum:.3f}deg,{distance:.7f}mm"
                           for mean, maximum, distance, i in worst))


if __name__ == "__main__":
    main()
