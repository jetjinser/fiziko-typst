#!/usr/bin/env python3
"""Reconstruct S104 source scanlines with 16.16 line intersections."""

import argparse
import math
from pathlib import Path


SCALE = 65536
MM_PER_BP = 25.4 / 72
# plain.mp's `mm` is a 16.16 numeric; the pinned source resolves it to
# 185771/65536 bp per millimetre rather than the exact 72/25.4 ratio.
SOURCE_BP_PER_MM = 185771 / SCALE
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
    lines = Path(log_path).read_text().splitlines()
    # The focused row records its actual path knots in bp as 16.16 chunks.
    # Prefer those over S104-SEG, whose decimal output is rounded to five
    # places and can hide endpoint errors of several 1e-5 mm.
    fixed_points = {}
    source_row = None
    for line in lines:
        fields = line.split()
        if len(fields) >= 2 and fields[0] == "FSROW":
            source_row = float(fields[1])
        elif (len(fields) == 8 and fields[0] == "S104-HATCHBP"
              and source_row is not None
              and abs(source_row - row) < 0.00001):
            _, index, x, xh, xl, y, yh, yl = fields
            fixed_points[int(index)] = (
                int(x) * SCALE + int(xh) * 256 + int(xl),
                int(y) * SCALE + int(yh) * 256 + int(yl),
            )
    if fixed_points:
        indexes = sorted(fixed_points)
        if indexes != list(range(len(indexes))) or len(indexes) < 2:
            raise ValueError("source HATCHBP indexes must be contiguous")
        first, last = fixed_points[indexes[0]], fixed_points[indexes[-1]]
        return [tuple(tuple(value / SCALE * MM_PER_BP for value in point)
                      for point in (first, last))]

    result = []
    for line in lines:
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
        raw = (round(x * SOURCE_BP_PER_MM * SCALE),
               round(y * SOURCE_BP_PER_MM * SCALE))
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


def rotated_panel(hatch_angle):
    angle = math.radians(hatch_angle)
    sine = round(math.sin(angle) * SCALE)
    cosine = round(math.cos(angle) * SCALE)
    source_points = [
        (round(x * SOURCE_BP_PER_MM * SCALE),
         round(y * SOURCE_BP_PER_MM * SCALE))
        for x, y in PANEL
    ]
    rotated = [rotate(point, sine, cosine, -1) for point in source_points]
    return [*rotated, rotated[0]]


def traced_rotated_panel(log_path, row):
    result = {}
    for line in Path(log_path).read_text().splitlines():
        fields = line.split()
        if (len(fields) == 9 and fields[0] == "S104-CLIP-POLY"
                and abs(float(fields[1]) - row) < 0.00001):
            _, _, index, x, xh, xl, y, yh, yl = fields
            result[int(index)] = (
                int(x) * SCALE + int(xh) * 256 + int(xl),
                int(y) * SCALE + int(yh) * 256 + int(yl),
            )
    if not result:
        return None
    indexes = sorted(result)
    if indexes != list(range(len(indexes))):
        raise ValueError("source rotated polygon indexes must be contiguous")
    return [result[i] for i in indexes]


def traced_clip_rows(log_path):
    rows = {}
    for line in Path(log_path).read_text().splitlines():
        fields = line.split()
        if fields and fields[0] == "S104-CLIP-ROW" and len(fields) == 8:
            _, row_text, whole, high, low, _, _, _ = fields
            row_fixed = int(whole) * SCALE + int(high) * 256 + int(low)
            rows[round(float(row_text) * SCALE)] = (row_fixed, {})
        elif fields and fields[0] == "S104-CLIP-ROT" and len(fields) == 9:
            _, row_text, index, x, xh, xl, y, yh, yl = fields
            key = round(float(row_text) * SCALE)
            row_fixed, points = rows.setdefault(key, (key, {}))
            points[int(index)] = (
                int(x) * SCALE + int(xh) * 256 + int(xl),
                int(y) * SCALE + int(yh) * 256 + int(yl),
            )
    complete = {}
    for row, (row_fixed, points) in rows.items():
        if sorted(points) == [0, 1]:
            complete[row_fixed] = [points[0], points[1]]
    return complete


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("--row", type=float, default=-6.37912)
    parser.add_argument("--frame-height", type=float, default=44.0)
    parser.add_argument("--hatch-angle", type=float, default=30.0)
    parser.add_argument("--all-rows", action="store_true")
    args = parser.parse_args()
    if args.all_rows:
        source_rows = traced_clip_rows(args.source_trace)
        if not source_rows:
            raise SystemExit("source trace has no complete S104-CLIP-ROW records")
        errors = []
        for row_fixed, source_points in source_rows.items():
            source = [
                (x / SCALE * MM_PER_BP,
                 args.frame_height - y / SCALE * MM_PER_BP)
                for x, y in source_points
            ]
            actual = intersections(row_fixed / SCALE,
                                   args.frame_height, args.hatch_angle)
            if len(actual) != 2:
                raise SystemExit(
                    f"row {row_fixed}: expected two candidate crossings, got {len(actual)}")
            errors.extend((math.dist(a, b), row_fixed, index, a, b)
                          for index, (a, b) in enumerate(zip(source, actual)))
        print(f"complete source rows: {len(source_rows)}")
        print(f"fixed reconstruction endpoint error mean/max: "
              f"{sum(item[0] for item in errors) / len(errors):.9f}/"
              f"{max(errors)[0]:.9f} mm")
        for error, row, endpoint, source, candidate in sorted(errors, reverse=True)[:5]:
            print(f"worst row {row / SCALE:.5f} endpoint {endpoint}: "
                  f"{error:.9f} mm; source={source}; candidate={candidate}")
        return
    source = source_segments(args.source_trace, args.row)[0]
    expected = tuple((x, args.frame_height - y) for x, y in source)
    actual = intersections(args.row, args.frame_height, args.hatch_angle)
    traced = traced_rotated_panel(args.source_trace, args.row)
    if traced is not None:
        candidate = rotated_panel(args.hatch_angle)
        if len(traced) != len(candidate):
            raise SystemExit(
                f"rotated polygon has {len(traced)} source and {len(candidate)} candidate points")
        residuals = [max(abs(a[0] - b[0]), abs(a[1] - b[1]))
                     for a, b in zip(traced, candidate)]
        print(f"rotated polygon max coordinate error: {max(residuals)} fixed units")
    if len(actual) != 2:
        raise SystemExit(f"expected two fixed-point crossings, found {len(actual)}")
    print(f"row={args.row:.5f}; source angle={args.hatch_angle:g}°")
    for index, (want, got) in enumerate(zip(expected, actual)):
        error = math.dist(want, got)
        print(f"endpoint {index}: source=({want[0]:.8f},{want[1]:.8f}) "
              f"fixed=({got[0]:.8f},{got[1]:.8f}) error={error:.8f} mm")


if __name__ == "__main__":
    main()
