#!/usr/bin/env python3
"""Replay one instrumented Fiziko cLine traversal from its grid samples."""

import argparse
import json
import math
import re
from pathlib import Path


def read_trace(path):
    level = None
    values = {}
    points = []
    steps = []
    for line in Path(path).read_text().splitlines():
        match = re.match(r"CLLEVEL\s+(-?[\d.]+)", line)
        if match:
            level = float(match.group(1))
            continue
        match = re.match(r"CLVALUE\s+(-?\d+)\s+(-?\d+)\s+(-?[\d.]+)", line)
        if match:
            i, j, value = match.groups()
            values[(int(i), int(j))] = float(value)
            continue
        match = re.match(r"CLPATH\s+\d+\s+(-?[\d.]+)\s+(-?[\d.]+)", line)
        if match:
            points.append(tuple(map(float, match.groups())))
            continue
        match = re.match(r"CLSTEP\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+", line)
        if match:
            steps.append(tuple(map(int, match.groups())))
    if level is None or not values or not points or not steps:
        raise ValueError("trace must include CLLEVEL, CLVALUE, CLPATH, and CLSTEP")
    return level, values, points, steps


def replay(level, values, start, width, height):
    visited = set()

    def intersections(i, j):
        corners = (
            values[(i, j)], values[(i, j + 1)],
            values[(i + 1, j)], values[(i + 1, j + 1)],
        )
        # cLine checks edges in this order and associates each hit with the
        # neighboring source cell in the corresponding direction.
        edges = (
            (corners[0], corners[1], (i, j), (i, j + 1), (-1, 0)),
            (corners[0], corners[2], (i, j), (i + 1, j), (0, -1)),
            (corners[1], corners[3], (i, j + 1), (i + 1, j + 1), (0, 1)),
            (corners[2], corners[3], (i + 1, j), (i + 1, j + 1), (1, 0)),
        )
        hits = []
        for a, b, p, q, direction in edges:
            a += level
            b += level
            sign_a = (a > 0) - (a < 0)
            sign_b = (b > 0) - (b < 0)
            if sign_a != sign_b:
                t = abs(-a / (b - a))
                hits.append((
                    (p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])),
                    direction,
                ))
        return hits

    def append_path(a, b):
        if not a:
            return b
        if not b:
            return a
        if math.dist(a[-1], b[0]) < 1e-7:
            return a + b[1:]
        return a + b

    def walk(i, j, direction=(0, 0), state=0):
        if not (0 <= i < height and 0 <= j < width):
            return [(i, j)]
        hits = intersections(i, j)
        if len(hits) < 2:
            return [(i, j)]
        p1, d1 = hits[0]
        p2, d2 = hits[1]
        if (i, j) in visited:
            return [((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)]

        visited.add((i, j))
        if direction == (0, 0):
            first = walk(i + d2[0], j + d2[1], d2, state + 1)
            second = walk(i + d1[0], j + d1[1], d1, state - 1)
            return append_path(append_path(first, [p1, p2]), second)

        if (i + d1[0], j + d1[1]) not in visited:
            next_direction, next_point = d1, p1
        elif (i + d2[0], j + d2[1]) not in visited:
            next_direction, next_point = d2, p2
        else:
            return [((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)]

        child = walk(
            i + next_direction[0], j + next_direction[1], next_direction,
            state + (1 if state > 0 else -1),
        )
        return (append_path(child, [next_point]) if state > 0
                else append_path([next_point], child))

    return walk(*start), visited


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("--width", type=int, default=55,
                        help="source cell count along j (default: M9's 55)")
    parser.add_argument("--height", type=int, default=33,
                        help="source cell count along i (default: M9's 33)")
    parser.add_argument("--tolerance", type=float, default=0.001,
                        help="maximum pointwise error in mm")
    args = parser.parse_args()

    level, values, source_points, steps = read_trace(args.trace)
    first = next((step for step in steps if 0 <= step[0] < args.height
                  and 0 <= step[1] < args.width), None)
    if first is None:
        raise ValueError("trace has no in-bounds seed cell")
    path, visited = replay(level, values, first[:2], args.width, args.height)
    expected = [(j, args.height - i) for i, j in source_points]
    path_local = [(j, args.height - i) for i, j in path]
    errors = [math.dist(a, b) for a, b in zip(path_local, expected)]
    max_error = max(errors) if len(path_local) == len(expected) else math.inf
    traced_cells = {(i, j) for i, j, state in steps
                    if state >= 0 and 0 <= i < args.height and 0 <= j < args.width}
    report = {
        "seed-cell": first[:2],
        "source-points": len(expected),
        "replayed-points": len(path_local),
        "source-cells": len(traced_cells),
        "replayed-cells": len(visited),
        "max-point-error-mm": max_error,
        "within-tolerance": max_error <= args.tolerance,
        "replayed-path": path_local,
    }
    print(json.dumps(report, indent=2))
    if not report["within-tolerance"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
