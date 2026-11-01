#!/usr/bin/env python3
"""Compare MetaPost S101 leaf coordinates with the Typst centerline sample.

Usage: compare_brush_trace.py MPOST_LOG TYPST_CENTERLINE_JSON
"""

import json
import math
import sys
from pathlib import Path


def project(point, segments):
    # MetaPost coordinates are bp with a bottom-left origin; Typst uses mm
    # and screen coordinates, so convert units and flip y in the 44 mm frame.
    x = point[0] / (72 / 25.4)
    y = 44 - point[1] / (72 / 25.4)
    best = (float("inf"), 0.0)
    for a, b, length, start in segments:
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        t = max(0.0, min(1.0, ((x - a[0]) * dx + (y - a[1]) * dy) / length**2))
        error = math.hypot(x - a[0] - t * dx, y - a[1] - t * dy)
        if error < best[0]:
            best = (error, start + t * length)
    return best


def parse_source(path):
    records = []
    record = None
    for line in Path(path).read_text().splitlines():
        if line == "S101 TRY":
            if record is not None:
                records.append(record)
            record = {"patterns": []}
        elif record is not None:
            if line.startswith("S101 WIDTH "):
                record["width"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 START "):
                record["start"] = tuple(map(float, line.split()[2:4]))
            elif line.startswith("S101 LENGTH "):
                record["length"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 ENDX "):
                record["end-x"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 ENDY "):
                record["end-y"] = float(line.rsplit(" ", 1)[1])
            elif line == "S101 PATTERN":
                record["patterns"].append({})
            elif line.startswith("S101 PARAM ") and record["patterns"]:
                n, rn, size, length = map(float, line.split()[2:6])
                record["patterns"][-1].update(
                    n=n, rn=int(rn), size=size, pattern_length=length
                )
            elif line.startswith("S101 OFF1 ") and record["patterns"]:
                record["patterns"][-1]["off1"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 OFF2 ") and record["patterns"]:
                record["patterns"][-1]["off2"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 CHANCE ") and record["patterns"]:
                record["patterns"][-1]["chance"] = float(line.rsplit(" ", 1)[1])
            elif line.startswith("S101 SINGLE ") and record["patterns"]:
                record["patterns"][-1]["single"] = float(line.rsplit(" ", 1)[1])
            elif line == "S101 EMPTY" and record["patterns"]:
                record["patterns"][-1]["empty"] = True
    if record is not None:
        records.append(record)
    return records


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)

    records = parse_source(sys.argv[1])
    leaves = [record for record in records if "width" in record]
    points = json.loads(Path(sys.argv[2]).read_text())
    segments = []
    arc_start = 0.0
    for a, b in zip(points, points[1:]):
        length = math.dist(a, b)
        segments.append((a, b, length, arc_start))
        arc_start += length

    endpoint_errors = []
    length_errors = []
    patterns = []
    for leaf in leaves:
        patterns.extend(leaf["patterns"])
        start = project(leaf["start"], segments)
        end = project((leaf["end-x"], leaf["end-y"]), segments)
        endpoint_errors.extend((start[0], end[0]))
        length_errors.append(
            abs(end[1] - start[1] - leaf["length"] / (72 / 25.4))
        )

    required = {"width", "start", "length", "end-x", "end-y"}
    if not leaves or any(not required.issubset(leaf) for leaf in leaves):
        raise SystemExit("incomplete S101 trace; regenerate the MetaPost log")

    def count_pattern_dots(pattern):
        if pattern["rn"] == 0:
            return int("single" in pattern)
        length = pattern["pattern_length"]
        period = length / pattern["rn"]
        offsets = [pattern["off1"]]
        if pattern["rn"] >= 3:
            offsets.append(period + pattern["off2"])
            period *= 2
        return sum(
            max(0, math.ceil((length - offset) / period)) for offset in offsets
        )

    dot_counts = [count_pattern_dots(pattern) for pattern in patterns]
    sizes = [pattern["size"] for pattern in patterns]

    print(f"terminal candidates: {len(records)}")
    print(f"drawable leaves: {len(leaves)}")
    print(f"local pattern calls: {len(patterns)}")
    print(f"source dots from dash phases: {sum(dot_counts)}")
    print(f"source dot diameter range: {min(sizes):.5f}–{max(sizes):.5f} pt")
    print(f"max endpoint distance: {max(endpoint_errors):.8f} mm")
    print(f"max leaf arc-length difference: {max(length_errors):.8f} mm")


if __name__ == "__main__":
    main()
