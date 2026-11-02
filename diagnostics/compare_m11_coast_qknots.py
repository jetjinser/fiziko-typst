#!/usr/bin/env python3
"""Pair one source recursive coast width-template node to Typst input knots.

Usage: compare_m11_coast_qknots.py MPOST_LOG TYPST_JSON LANDMASS DEPTH
"""

import json
import math
import sys
from pathlib import Path

PT_TO_MM = 25.4 / 72


def source_knots(log_path, landmass, depth):
    active = False
    current = []
    for line in Path(log_path).read_text().splitlines():
        if line.startswith("M11-COAST-BEGIN "):
            active = int(line.split()[1]) == landmass
            current = []
            continue
        if line.startswith("M11-COAST-END "):
            active = False
            continue
        if not active:
            continue
        fields = line.split()
        if fields[:1] == ["S101-QKNOT"] and len(fields) == 7:
            if int(fields[1]) == depth:
                knot_index = int(fields[2])
                if knot_index == 0:
                    current = []
                current.append((knot_index, *map(float, fields[3:])))
        elif fields[:2] == ["S101", "NODE"] and int(fields[2]) == depth:
            if current:
                return current
            raise SystemExit(f"depth-{depth} source node has no q knots")
    raise SystemExit(f"no depth-{depth} source node for landmass {landmass}")


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    log, trace_path = sys.argv[1:3]
    landmass, depth = map(int, sys.argv[3:5])
    knots = source_knots(log, landmass, depth)
    trace = json.loads(Path(trace_path).read_text())
    entry = next((item for item in trace if item["landmass"] == landmass), None)
    if entry is None:
        raise SystemExit(f"no Typst trace for landmass {landmass}")
    samples = entry["width-samples"]
    center = (19.0, 22.0)
    pairs = []
    for index, qx, qy, px, py in knots:
        point = (center[0] + px * PT_TO_MM, center[1] - py * PT_TO_MM)
        nearest = min(samples, key=lambda sample: math.dist(point, sample["point"]))
        error = math.dist(point, nearest["point"])
        width_error = abs(qy * PT_TO_MM - nearest["width"])
        pairs.append((int(index), error, width_error))

    matched = [item for item in pairs if item[1] <= 0.001]
    print(f"landmass {landmass} depth {depth}: {len(matched)}/{len(pairs)} knots "
          "pair to Typst samples within 0.001 mm")
    if matched:
        print("matched position error mean/max: "
              f"{sum(item[1] for item in matched) / len(matched):.8f}/"
              f"{max(item[1] for item in matched):.8f} mm")
        print("matched width error mean/max: "
              f"{sum(item[2] for item in matched) / len(matched):.8f}/"
              f"{max(item[2] for item in matched):.8f} mm")
    for index, error, width_error in pairs:
        if error > 0.001:
            print(f"unpaired source knot {index}: nearest position error "
                  f"{error:.6f} mm; width difference {width_error:.8f} mm")


if __name__ == "__main__":
    main()
