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
    for line in Path(sys.argv[1]).read_text().splitlines():
        fields = line.split()
        if len(fields) == 5 and fields[0] == "M11COAST":
            mass = int(fields[1])
            # Source coordinates are local to the globe; map them to the
            # comparison's center and account for MetaPost's upward y axis.
            source[mass].append((19 + float(fields[3]), 22 - float(fields[4])))

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
        print(f"mass {mass}: source samples={len(errors)}, Typst runs="
              f"{[len(run) for run in runs]}, nearest error median/max="
              f"{statistics.median(errors):.6f}/{max(errors):.6f} mm")
        print(f"  source first sample maps to run {start_run} point {start_idx} "
              f"({start_error:.6f} mm); first source sample per run="
              f"{first_by_run}; run order by first nearest sample="
              f"{source_run_order}")


if __name__ == "__main__":
    main()
