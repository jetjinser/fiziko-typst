#!/usr/bin/env python3
"""Compare traced source coast samples with Typst's visible path runs.

Usage: compare_m11_coast_samples.py SOURCE_LOG TYPST_JSON
"""

import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source: dict[int, list[tuple[float, float]]] = defaultdict(list)
    source_times: dict[int, list[float]] = defaultdict(list)
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if len(fields) == 5 and fields[0] == "M11COAST":
            mass = int(fields[1])
            # Source coordinates are local to the globe; map them to the
            # comparison's center and account for MetaPost's upward y axis.
            source[mass].append((19 + float(fields[3]), 22 - float(fields[4])))
            source_times[mass].append(float(fields[2]))

    trace = json.loads(Path(sys.argv[2]).read_text())
    for entry in trace["landmasses"]:
        mass = entry["landmass"]
        runs = entry["points"]
        if not source[mass] or not runs:
            continue
        flat = [(run_id, idx, (point["x"], point["y"]))
                for run_id, run in enumerate(runs)
                for idx, point in enumerate(run)]
        errors, nearest = [], []
        for p in source[mass]:
            dist, run_id, idx, q = min(
                (math.dist(p, q), run_id, idx, q) for run_id, idx, q in flat)
            errors.append(dist)
            nearest.append((run_id, idx, dist))
        start_run, start_idx, start_error = nearest[0]
        first_by_run = {r: next(i for i, hit in enumerate(nearest)
                                 if hit[0] == r) for r in range(len(runs))
                        if any(hit[0] == r for hit in nearest)}
        source_run_order = sorted(first_by_run, key=first_by_run.get)
        outline_entry = next((item for item in trace["outline-arcs"]
                              if item["landmass"] == mass), None)
        outline_match = None
        if outline_entry:
            first_source = source[mass][0]
            outline_match = min(
                (math.dist(first_source, (p["x"], p["y"])), i)
                for i, p in enumerate(outline_entry["outline-points"]))
            source_length = source_times[mass][-1]
            points = outline_entry["outline-points"]
            times = outline_entry["source-times"]
            start_index = outline_match[1]
            points = points[start_index:] + points[:start_index]
            times = (times[start_index:]
                     + [t + outline_entry["source-time-end"]
                        for t in times[:start_index]])
            offset = source_times[mass][0] - times[0]
            paired_indices = []
            previous = 0
            for point in points:
                end = min(len(source[mass]), previous + 512)
                _, matched_index = min(
                    (math.dist((point["x"], point["y"]), source[mass][j]), j)
                    for j in range(previous, end))
                paired_indices.append(matched_index)
                previous = matched_index
            spatial_errors = [math.dist((point["x"], point["y"]),
                                        source[mass][j])
                              for point, j in zip(points, paired_indices)]
            time_errors = [abs(source_times[mass][j] - t - offset)
                           for t, j in zip(times, paired_indices)]
            close = [error for error, distance in zip(time_errors, spatial_errors)
                     if distance <= 0.001]
        print(f"mass {mass}: source samples={len(errors)}, Typst runs="
              f"{[len(run) for run in runs]}, nearest error median/max="
              f"{statistics.median(errors):.6f}/{max(errors):.6f} mm")
        print(f"  source first sample maps to run {start_run} point {start_idx} "
              f"({start_error:.6f} mm); first source sample per run="
              f"{first_by_run}; run order by first nearest sample="
              f"{source_run_order}")
        if outline_match:
            print(f"  source path start maps to outline point {outline_match[1]} "
                  f"of {len(outline_entry['outline-points'])} "
                  f"({outline_match[0]:.6f} mm)")
            print(f"  source-time offset at first mapped point={offset:.5f}; "
                  "after offset, "
                  f"time error median/max="
                  f"{statistics.median(time_errors):.5f}/"
                  f"{max(time_errors):.5f}; spatial error median/max="
                  f"{statistics.median(spatial_errors):.6f}/"
                  f"{max(spatial_errors):.6f} mm; source/Typst path-time "
                  f"length={source_length:.5f}/{outline_entry['source-time-end']:.5f}")
            if close:
                print(f"  for {len(close)}/{len(time_errors)} points within "
                      f"0.001 mm spatial error, path-time error median/max="
                      f"{statistics.median(close):.5f}/{max(close):.5f}")


if __name__ == "__main__":
    main()
