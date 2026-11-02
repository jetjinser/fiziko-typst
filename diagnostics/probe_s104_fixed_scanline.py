#!/usr/bin/env python3
"""Reconstruct one S104 source scanline with 16.16 line intersections."""

import argparse
import math
from pathlib import Path


SCALE = 65536
MM_PER_BP = 25.4 / 72
PANEL = ((8.0, 36.0), (56.0, 31.0), (50.0, 8.0), (5.0, 13.0))


def fixed_ratio(numerator, denominator):
    magnitude = abs(numerator)
    result = (2 * magnitude + abs(denominator)) // (2 * abs(denominator))
    return -result if (numerator < 0) != (denominator < 0) else result


def rotate(point, sine, cosine, direction):
    x, y = point
    sine *= direction
    mul = lambda a, b: fixed_ratio(a * b, SCALE)
    return mul(x, cosine) - mul(y, sine), mul(x, sine) + mul(y, cosine)


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def source_segments(log_path, row):
    result = []
    for line in Path(log_path).read_text().splitlines():
        fields = line.split()
        if (len(fields) >= 7 and fields[0] == "S104-SEG"
                and int(fields[2]) == 0
                and abs(float(fields[1]) - row) < 0.00001):
            result.append((
                (float(fields[3]), float(fields[4])),
                (float(fields[5]), float(fields[6])),
            ))
    if not result:
        raise ValueError(f"no source root segment found for row {row}")
    return result


def intersections(row, frame_height, hatch_angle):
    angle = math.radians(hatch_angle)
    sine = round(math.sin(angle) * SCALE)
    cosine = round(math.cos(angle) * SCALE)
    points = []
    for x, y in PANEL:
        # MetaPost defines the panel in its y-up source frame. Apply the
        # fixture's page flip only after rotating the intersection back.
        raw = (round(x / MM_PER_BP * SCALE), round(y / MM_PER_BP * SCALE))
        points.append(rotate(raw, sine, cosine, -1))
    y = round(row * SCALE)
    xmin = min(point[0] for point in points)
    xmax = max(point[0] for point in points)
    ray = ((xmax - xmin, 0),)
    hits = []
    for a, b in zip(points, points[1:] + points[:1]):
        if not ((a[1] <= y < b[1]) or (b[1] <= y < a[1])):
            continue
        edge = (b[0] - a[0], b[1] - a[1])
        offset = (a[0] - xmin, a[1] - y)
        denominator = cross(ray[0], edge)
        numerator = cross(offset, edge)
        edge_numerator = cross(offset, ray[0])
        if denominator == 0:
            continue
        if denominator < 0:
            denominator, numerator, edge_numerator = (
                -denominator, -numerator, -edge_numerator)
        if not (0 <= numerator <= denominator and 0 <= edge_numerator <= denominator):
            continue
        t = fixed_ratio(numerator * SCALE, denominator)
        point = (xmin + fixed_ratio(ray[0][0] * t, SCALE), y)
        page = rotate(point, sine, cosine, 1)
        hits.append((point[0], (page[0] / SCALE * MM_PER_BP,
                                frame_height - page[1] / SCALE * MM_PER_BP)))
    return [point for _, point in sorted(hits)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("--row", type=float, default=-6.37912)
    parser.add_argument("--frame-height", type=float, default=44.0)
    parser.add_argument("--hatch-angle", type=float, default=30.0)
    args = parser.parse_args()
    source = source_segments(args.source_trace, args.row)[0]
    expected = tuple((x, args.frame_height - y) for x, y in source)
    actual = intersections(args.row, args.frame_height, args.hatch_angle)
    if len(actual) != 2:
        raise SystemExit(f"expected two fixed-point crossings, found {len(actual)}")
    print(f"row={args.row:.5f}; source angle={args.hatch_angle:g}°")
    for index, (want, got) in enumerate(zip(expected, actual)):
        error = math.dist(want, got)
        print(f"endpoint {index}: source=({want[0]:.8f},{want[1]:.8f}) "
              f"fixed=({got[0]:.8f},{got[1]:.8f}) error={error:.8f} mm")


if __name__ == "__main__":
    main()
