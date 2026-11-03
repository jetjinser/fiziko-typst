#!/usr/bin/env python3
"""Compare source M11 lighting callbacks against every paired Typst tube lane.

Usage: compare_m11_all_shading_samples.py MPOST_LOG TYPOGRAPHY_TRACE_JSON
"""

import json
import math
import statistics
from collections import defaultdict
from pathlib import Path

from compare_m11_shading_samples import (
    nearest_sample,
    source_samples,
    summarize,
    y_flipped_lightness,
)


CALL_SEGMENTS = {
    1: (1, 1),
    2: (0, 0),
    3: (0, 2),
    4: (1, 0),
    5: (1, 2),
    6: (0, 1),
}


def read_typst(path: Path):
    data = json.loads(path.read_text())
    while data and isinstance(data[0], list):
        data = data[0]
    segments = {}
    for trace in data:
        candidates = []
        for lane in trace["inner-lanes"]:
            candidates.append({
                "name": f"inner-{lane['lane']}",
                "u": lane["u"],
                "points": lane["points"],
                "width": lane["widths"],
                "light": lane["lightness"],
                "candidate-light": [
                    y_flipped_lightness(normal, slope, lane["u"])
                    for normal, slope in zip(lane["normals"], lane["radius-slopes"])
                ],
            })
        for lane in trace["edge-lanes"]:
            candidates.append({
                "name": f"edge-{lane['side']:+g}",
                "u": lane["side"],
                "points": lane["points"],
                "width": lane["widths"],
                "light": lane["lightness"],
                "candidate-light": [
                    y_flipped_lightness(normal, slope, lane["side"])
                    for normal, slope in zip(lane["normals"], lane["radius-slopes"])
                ],
            })
        segments[(trace["strand"], trace["segment"])] = candidates
    return segments


def main():
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    args = parser.parse_args()
    source, shadows = source_samples(args.source_log)
    typst = read_typst(args.typst_trace)

    for call, segment_id in CALL_SEGMENTS.items():
        rows = []
        lane_matches = defaultdict(int)
        for (source_call, source_lane), source_rows in source.items():
            if source_call != call:
                continue
            for row in source_rows:
                if row["width"] is None:
                    continue
                choices = []
                for lane in typst[segment_id]:
                    points = [tuple(map(float, point)) for point in lane["points"]]
                    fields = {
                        "width": list(map(float, lane["width"])),
                        "light": list(map(float, lane["light"])),
                        "candidate-light": list(map(float, lane["candidate-light"])),
                    }
                    distance, values = nearest_sample(row["point"], points, fields)
                    choices.append((distance, lane, values))
                distance, lane, values = min(choices, key=lambda item: item[0])
                lane_matches[(source_lane, lane["name"])] += 1
                is_shadow = any(
                    math.dist(row["point"], shadow) < 1e-7
                    for shadow in shadows.get((call, source_lane), ())
                )
                candidate_light = 1.0 if is_shadow else values["candidate-light"]
                current_width = values["width"]
                candidate_width = (
                    current_width * candidate_light / values["light"]
                    if values["light"] > 1e-9 else current_width
                )
                rows.append((row["effective-width"], current_width, candidate_width,
                             distance, is_shadow, source_lane, lane["name"]))
        baseline = [(row[0], row[1]) for row in rows]
        candidate = [(row[0], row[2]) for row in rows]
        bmae, bmax, _, _ = summarize(baseline)
        cmae, cmax, _, _ = summarize(candidate)
        mean_distance = statistics.mean(row[3] for row in rows)
        shadow_count = sum(row[4] for row in rows)
        pairs = ", ".join(
            f"k{source_lane}->{lane}:{count}"
            for (source_lane, lane), count in sorted(lane_matches.items())
        )
        print(f"call={call} samples={len(rows)} shadowed={shadow_count} "
              f"distance-mean={mean_distance:.6g}mm "
              f"width-MAE baseline/candidate={bmae:.6f}/{cmae:.6f}mm "
              f"max={bmax:.6f}/{cmax:.6f}mm")
        print(f"  pairings: {pairs}")
        for source_lane in range(9):
            subset = [row for row in rows if row[5] == source_lane]
            if not subset:
                continue
            lane_baseline = summarize([(row[0], row[1]) for row in subset])[0]
            lane_candidate = summarize([(row[0], row[2]) for row in subset])[0]
            print(f"  k={source_lane}: "
                  f"width-MAE baseline/candidate="
                  f"{lane_baseline:.6f}/{lane_candidate:.6f}mm")


if __name__ == "__main__":
    main()
