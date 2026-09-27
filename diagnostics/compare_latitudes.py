#!/usr/bin/env python3
"""Compare Figure 12 latitude traces from MetaPost and Typst.

Usage: compare_latitudes.py METAPOST_LOG TYPST_JSON OUTPUT_CSV
The MetaPost log comes from the diagnostic copy of fiziko.mp with LAT, BR,
OL, TL, and TB messages. The Typst JSON comes from the with-trace option.
"""

import csv
import json
import re
import sys
from pathlib import Path

BP_TO_MM = 25.4 / 72


def metapost_rows(path):
    rows = []
    sphere = 0
    previous_latitude = 0
    current = None
    for line in Path(path).read_text().splitlines():
        marker = re.search(r"LAT=(\d+) SPH=", line)
        if marker:
            latitude = int(marker.group(1))
            if current is not None:
                rows.append(current)
            if latitude < previous_latitude:
                sphere += 1
            previous_latitude = latitude
            current = dict(sphere=sphere + 1, latitude=latitude, path_mm=0,
                           width_min_mm=0, width_max_mm=0, outer_leaves=0,
                           thin_leaves=0, dash_calls=0, knots=[])
            continue
        if current is None:
            continue
        brush = re.search(r"BR l=([\d.]+) min=([\d.]+) max=([\d.]+)", line)
        if brush:
            current["path_mm"] = float(brush.group(1)) * BP_TO_MM
            current["width_min_mm"] = float(brush.group(2)) * BP_TO_MM
            current["width_max_mm"] = float(brush.group(3)) * BP_TO_MM
        knot = re.search(r"BW x=([\d.]+) w=([\d.]+)", line)
        if knot:
            current["knots"].append((float(knot.group(1)) * BP_TO_MM,
                                     float(knot.group(2)) * BP_TO_MM))
        if "OL solid" in line or "OL thin" in line:
            current["outer_leaves"] += 1
        if line.strip() == "TL":
            current["thin_leaves"] += 1
        if "TB w=" in line:
            current["dash_calls"] += 1
    if current is not None:
        rows.append(current)
    return {(row["sphere"], row["latitude"]): row for row in rows}


def typst_rows(path):
    traces = json.loads(Path(path).read_text())
    return {
        (sphere, row["latitude"]): {
            "sphere": sphere,
            "latitude": row["latitude"],
            "path_mm": row["path-length"],
            "width_min_mm": row["width-min"],
            "width_max_mm": row["width-max"],
            "outer_leaves": row["outer-leaves"],
            "thin_leaves": row["thin-leaves"],
            "dash_calls": row["dash-calls"],
            "knots": list(zip(row["knot-s"], row["knot-w"])),
        }
        for sphere, trace in enumerate(traces, start=1)
        for row in trace
    }


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    source = metapost_rows(sys.argv[1])
    typst = typst_rows(sys.argv[2])
    fields = ("path_mm", "width_min_mm", "width_max_mm", "outer_leaves",
              "thin_leaves", "dash_calls")
    with Path(sys.argv[3]).open("w", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(["sphere", "latitude"] +
                        [f"{side}_{field}" for field in fields
                         for side in ("mp", "typst")] +
                        ["mp_knots", "typst_knots", "max_knot_arc_error_mm",
                         "max_knot_width_error_mm", "dash_deficit"])
        for key in sorted(source.keys() | typst.keys()):
            mp = source.get(key, {})
            tp = typst.get(key, {})
            mp_knots = mp.get("knots", [])
            tp_knots = tp.get("knots", [])
            if len(mp_knots) == len(tp_knots) and mp_knots:
                arc_error = max(abs(a[0] - b[0]) for a, b in zip(mp_knots, tp_knots))
                width_error = max(abs(a[1] - b[1]) for a, b in zip(mp_knots, tp_knots))
            else:
                arc_error = width_error = ""
            writer.writerow(list(key) +
                            [row.get(field, "") for field in fields
                             for row in (mp, tp)] +
                            [len(mp_knots), len(tp_knots), arc_error, width_error] +
                            [mp.get("dash_calls", 0) - tp.get("dash_calls", 0)])


if __name__ == "__main__":
    main()
