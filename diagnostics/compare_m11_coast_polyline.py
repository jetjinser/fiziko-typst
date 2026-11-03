#!/usr/bin/env python3
"""Measure source coast samples against the Typst closed outline polyline.

Usage: compare_m11_coast_polyline.py SOURCE_LOG GEOMETRY_JSON
"""

import json
import math
import sys
from collections import defaultdict
from pathlib import Path


def point_segment_distance(point, start, end):
    dx, dy = end[0] - start[0], end[1] - start[1]
    length2 = dx * dx + dy * dy
    if length2 == 0:
        return math.dist(point, start)
    t = max(0.0, min(1.0,
        ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / length2))
    projection = (start[0] + t * dx, start[1] + t * dy)
    return math.dist(point, projection)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source = defaultdict(list)
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if len(fields) == 5 and fields[0] == "M11COAST":
            source[int(fields[1])].append(
                (19 + float(fields[3]), 22 - float(fields[4])))

    trace = json.loads(Path(sys.argv[2]).read_text())
    for outline in trace["outline-arcs"]:
        mass = outline["landmass"]
        samples = source[mass]
        points = [(point["x"], point["y"])
                  for point in outline["outline-points"]]
        segments = list(zip(points, points[1:] + points[:1]))
        distances = [min(point_segment_distance(sample, a, b)
                         for a, b in segments)
                     for sample in samples]
        ordered = sorted(distances)
        quantile = lambda p: ordered[round((len(ordered) - 1) * p)]
        print(f"mass {mass}: samples={len(samples)} source-to-outline "
              f"distance median/p90/p99/max="
              f"{quantile(0.50):.6f}/{quantile(0.90):.6f}/"
              f"{quantile(0.99):.6f}/{ordered[-1]:.6f} mm")


if __name__ == "__main__":
    main()
