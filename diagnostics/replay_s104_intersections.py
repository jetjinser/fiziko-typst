#!/usr/bin/env python3
"""Replay MetaPost's recursive intersection search on an instrumented S104 row.

Usage: replay_s104_intersections.py MPOST_LOG ROW

This is a diagnostic model, not a replacement for MetaPost's fixed-point
implementation. It follows the published 17-level cubic bisection and the
source macro's forward/reversed-path selection so mismatches can be localized.
"""

import sys
from collections import defaultdict
from pathlib import Path


def fixed(high: str, low: str) -> float:
    return (int(high) + int(low) / 256) / 256


def midpoint(a, b):
    return tuple((x + y) / 2 for x, y in zip(a, b))


def bisect(curve):
    a, b, c, d = curve
    ab, bc, cd = midpoint(a, b), midpoint(b, c), midpoint(c, d)
    abc, bcd = midpoint(ab, bc), midpoint(bc, cd)
    m = midpoint(abc, bcd)
    return (a, ab, abc, m), (m, bcd, cd, d)


def intersects_box(a, b, tolerance):
    for axis in (0, 1):
        aa = [point[axis] for point in a]
        bb = [point[axis] for point in b]
        if min(aa) > max(bb) + tolerance or min(bb) > max(aa) + tolerance:
            return False
    return True


def cubic_intersection(a, b, tolerance_step):
    """Return midpoint parameters for the first overlapping pair, if any."""
    visits = 0

    def descend(left, right, level, left_index, right_index):
        nonlocal visits
        visits += 1
        # The pinned MetaPost source stores this tolerance in scaled units.
        # The trace controls are in points, hence convert the tolerance back.
        tolerance = (2 * tolerance_step * level) / 65536
        if not intersects_box(left, right, tolerance):
            return None
        if level == 17:
            scale = 2**17
            return ((left_index + 0.5) / scale,
                    (right_index + 0.5) / scale)
        if visits > 5000:
            return None
        left0, left1 = bisect(left)
        right0, right1 = bisect(right)
        for i, lcurve in enumerate((left0, left1)):
            for j, rcurve in enumerate((right0, right1)):
                result = descend(lcurve, rcurve, level + 1,
                                 left_index * 2 + i, right_index * 2 + j)
                if result is not None:
                    return result
        return None

    return descend(a, b, 0, 0, 0)


def path_intersection(ray, path, tolerance_step):
    for segment, curve in enumerate(path):
        result = cubic_intersection(ray, curve, tolerance_step)
        if result is not None:
            return result[0], segment + result[1]
    return -1.0, -1.0


def intersection_with_retry(ray, path):
    # MetaPost path_intersection retries with increasing overlap tolerance.
    for tolerance_step in (0, 3, 6):
        result = path_intersection(ray, path, tolerance_step)
        if result[0] >= 0:
            return result
    return -1.0, -1.0


def first_intersection_times(ray, path):
    direct = intersection_with_retry(ray, path)
    reverse = intersection_with_retry(
        ray, [tuple(reversed(curve)) for curve in reversed(path)])
    # The upstream macro first assigns t1/t2, adjusts for reversed-path time,
    # and only then applies its special no-forward-hit fallback to raw t2.
    if direct[0] < 0:
        return reverse
    if direct[0] < reverse[0]:
        return direct
    return reverse[0], len(path) - reverse[1]


def cubic_value(controls, t):
    u = 1 - t
    a, b, c, d = controls
    return u**3 * a + 3 * u**2 * t * b + 3 * u * t**2 * c + t**3 * d


def decode(log, row):
    nodes = defaultdict(lambda: {"rays": defaultdict(dict), "x": {}, "y": {}})
    for line in Path(log).read_text().splitlines():
        p = line.split()
        if not p or len(p) < 3 or p[0] not in {
            "S104-ORAY", "S104-OXCTRL", "S104-OCTRL", "S104-OFIX", "S104-HIT"
        }:
            continue
        if abs(float(p[1]) - row) > 0.00001:
            continue
        node = nodes[int(p[2])]
        if p[0] == "S104-ORAY":
            node["rays"][int(p[3])][int(p[4])] = fixed(p[5], p[6])
        elif p[0] == "S104-OXCTRL":
            node["x"][int(p[4])] = [fixed(p[i], p[i + 1])
                                    for i in range(5, 13, 2)]
        elif p[0] == "S104-OCTRL":
            node["y"][int(p[4])] = [fixed(p[i], p[i + 1])
                                    for i in range(5, 13, 2)]
        elif p[0] == "S104-OFIX":
            node["source_cut"] = fixed(p[10], p[11])
            node["threshold"] = fixed(p[8], p[9])
        elif p[0] == "S104-HIT":
            node["source_hits"] = tuple(map(float, p[7:9]))
            node["midpoint_x"] = float(p[6])
    return nodes


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    row = float(sys.argv[2])
    nodes = decode(sys.argv[1], row)
    compared = []
    for serial, node in nodes.items():
        if "source_cut" not in node or node["source_cut"] <= 0:
            continue
        if len(node["x"]) != len(node["y"]) or not node["rays"][1]:
            continue
        path = [list(zip(node["x"][i], node["y"][i]))
                for i in sorted(node["x"])]
        threshold = node["threshold"]
        hits = []
        for ray_id in (1, 2):
            ray = [(node["rays"][ray_id][i], threshold) for i in range(4)]
            hits.append(first_intersection_times(ray, path)[1])
        midpoint = node["midpoint_x"]
        candidates = []
        for hit in hits:
            if hit < 0:
                continue
            segment = min(int(hit), len(path) - 1)
            local_t = hit - segment
            x = cubic_value(node["x"][segment], local_t)
            candidates.append((abs(x - midpoint), hit))
        replayed = min(candidates)[1] if candidates else -1.0
        error = abs(replayed - node["source_cut"])
        compared.append((serial, node["source_cut"], hits, replayed, error))

    if not compared:
        raise SystemExit("no source cuts with complete ray/control traces found")
    errors = [item[4] for item in compared]
    print(f"row {row:g}: {len(compared)} source cuts")
    print(f"mean absolute time error: {sum(errors) / len(errors):.9g}")
    print(f"maximum absolute time error: {max(errors):.9g}")
    print(f"within 1/65536: {sum(e <= 1 / 65536 for e in errors)}")
    print("serial source-time ray-times replayed-time error")
    for item in compared[:20]:
        serial, source, hits, replayed, error = item
        print(f"{serial:6d} {source:12.8f} {str(hits):>28s} "
              f"{replayed:12.8f} {error:.8g}")


if __name__ == "__main__":
    main()
