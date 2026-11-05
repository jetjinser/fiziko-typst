#!/usr/bin/env python3
"""Compare source S104 hatch points/arcs with a Typst row trace."""

import argparse
import json
import math
from pathlib import Path

from compare_s104_row_calls import source_rows


SCALE = 65536
MM_PER_BP = 25.4 / 72


def fixed_chunks(whole, high, low):
    return whole * SCALE + high * 256 + low


def source_records(path, row):
    points = {}
    arcs = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "S104-HATCHBP":
            _, source_row, index, x, xh, xl, y, yh, yl = fields
            if abs(float(source_row) - row) > 0.00001:
                continue
            points[int(index)] = (
                fixed_chunks(int(x), int(xh), int(xl)),
                fixed_chunks(int(y), int(yh), int(yl)),
            )
        elif fields[0] == "S104-HATCHARC":
            _, source_row, index, whole, high, low = fields
            if abs(float(source_row) - row) > 0.00001:
                continue
            arcs[int(index)] = fixed_chunks(
                int(whole), int(high), int(low))
    if len(points) < 2 or len(arcs) != len(points):
        raise ValueError("source trace needs matching HATCHBP and HATCHARC records")
    indexes = sorted(points)
    if indexes != list(range(len(indexes))):
        raise ValueError("source hatch point indexes must be contiguous from zero")
    return [points[i] for i in indexes], [arcs[i] for i in indexes]


def typst_row(path, row):
    data = json.loads(Path(path).read_text())
    rows = data["rows"] if isinstance(data, dict) else data
    matches = [item for item in rows if item.get("row") == row]
    if len(matches) != 1:
        raise ValueError(f"expected one Typst row {row}, found {len(matches)}")
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_trace", type=Path)
    parser.add_argument("typst_rows", type=Path)
    parser.add_argument("--row", type=int, default=93)
    parser.add_argument("--frame-height", type=float, default=44)
    args = parser.parse_args()

    row = typst_row(args.typst_rows, args.row)
    typst_data = json.loads(Path(args.typst_rows).read_text())
    typst_rows = typst_data["rows"] if isinstance(typst_data, dict) else typst_data
    row_index = next(index for index, item in enumerate(typst_rows)
                     if item.get("row") == args.row)
    source_y = source_rows(args.source_trace)[row_index]["row"]
    source_points, source_arcs = source_records(args.source_trace, source_y)
    start, end = row["start"], row["end"]
    times = row["sample-times"]
    if len(times) != len(source_points):
        raise ValueError(
            f"source has {len(source_points)} points, Typst has {len(times)} sample times")

    errors = []
    for index, ((x, y), t) in enumerate(zip(source_points, times)):
        source = (x / SCALE * MM_PER_BP,
                  args.frame_height - y / SCALE * MM_PER_BP)
        typst = (start[0] + (end[0] - start[0]) * t,
                 start[1] + (end[1] - start[1]) * t)
        error = math.dist(source, typst)
        errors.append(error)
        print(f"point {index}: t={t:.10f} source=({source[0]:.9f},"
              f"{source[1]:.9f}) typst=({typst[0]:.9f},{typst[1]:.9f}) "
              f"error={error:.9f} mm")

    arc_errors = []
    for index in range(len(source_points) - 1):
        a, b = source_points[index], source_points[index + 1]
        chord = round(math.hypot(b[0] - a[0], b[1] - a[1]))
        arc = source_arcs[index + 1] - source_arcs[index]
        residual = arc - chord
        arc_errors.append(abs(residual))
        print(f"segment {index}: source arc={arc} chord={chord} "
              f"residual={residual} fixed bp units")

    print(f"point error mean/max: {sum(errors) / len(errors):.9f}/"
          f"{max(errors):.9f} mm")
    print(f"source arc/chord residual max: {max(arc_errors)} fixed bp units")


if __name__ == "__main__":
    main()
