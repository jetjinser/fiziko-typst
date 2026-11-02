#!/usr/bin/env python3
"""Pair source M11 tube dash leaves with one sampled Typst knot lane."""

import argparse
import json
import math
from pathlib import Path


def project_to_polyline(point, points, cumulative):
    best = (math.inf, 0.0)
    for index, (a, b) in enumerate(zip(points, points[1:])):
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        span2 = dx * dx + dy * dy
        t = 0.0 if span2 == 0 else max(
            0.0,
            min(1.0, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / span2),
        )
        projected = (a[0] + t * dx, a[1] + t * dy)
        error = math.dist(point, projected)
        arc = cumulative[index] + t * (cumulative[index + 1] - cumulative[index])
        if error < best[0]:
            best = (error, arc)
    return best


def lane_arcs(points):
    cumulative = [0.0]
    for a, b in zip(points, points[1:]):
        cumulative.append(cumulative[-1] + math.dist(a, b))
    return cumulative


def read_source_dashes(path, tube_call, lane):
    leaves = []
    prefix = f"M11DASH {tube_call} {lane} "
    for line in path.read_text().splitlines():
        if not line.startswith(prefix):
            continue
        fields = line.split()
        start = (float(fields[6]), float(fields[7]))
        end = (float(fields[8]), float(fields[9]))
        leaves.append({
            "depth": int(fields[3]),
            "width-mm": float(fields[4]),
            "length-mm": float(fields[5]),
            "start": start,
            "end": end,
        })
    if not leaves:
        raise ValueError(f"no M11DASH records for call {tube_call}, lane {lane}")
    return leaves


def compare(source_log, typst_json, tube_call, source_lane, strand, segment,
            typst_lane, candidate):
    trace = json.loads(typst_json.read_text())
    interval = next((item for item in trace
                     if item["strand"] == strand and item["segment"] == segment), None)
    if interval is None:
        raise ValueError(f"no Typst trace for strand {strand}, segment {segment}")
    lane = next((item for item in interval["inner-lanes"]
                 if item["lane"] == typst_lane and item["piece"] == 0), None)
    if lane is None or not lane.get("points"):
        raise ValueError(f"no sampled Typst lane {typst_lane}, piece 0")
    points = lane["points"]
    cumulative = lane_arcs(points)

    source = read_source_dashes(source_log, tube_call, source_lane)
    source_intervals = []
    for leaf in source:
        start_error, start_arc = project_to_polyline(leaf["start"], points, cumulative)
        end_error, end_arc = project_to_polyline(leaf["end"], points, cumulative)
        source_intervals.append({
            "start-mm": min(start_arc, end_arc),
            "end-mm": max(start_arc, end_arc),
            "projection-error-mm": max(start_error, end_error),
            "depth": leaf["depth"],
            "width-mm": leaf["width-mm"],
            "length-mm": leaf["length-mm"],
        })

    nodes = lane["candidate-nodes" if candidate else "nodes"]
    typst_intervals = []
    for node in nodes:
        if node.get("stage") != "thin" or not node.get("dash"):
            continue
        start_error, start_arc = project_to_polyline(node["path-start"], points, cumulative)
        end_error, end_arc = project_to_polyline(node["path-end"], points, cumulative)
        typst_intervals.append({
            "start-mm": min(start_arc, end_arc),
            "end-mm": max(start_arc, end_arc),
            "projection-error-mm": max(start_error, end_error),
            "depth": node["depth"],
            "length-mm": node["length"],
        })

    source_intervals.sort(key=lambda item: item["start-mm"])
    typst_intervals.sort(key=lambda item: item["start-mm"])
    paired = list(zip(source_intervals, typst_intervals))
    endpoint_errors = [
        error
        for source_leaf, typst_leaf in paired
        for error in (
            abs(source_leaf["start-mm"] - typst_leaf["start-mm"]),
            abs(source_leaf["end-mm"] - typst_leaf["end-mm"]),
        )
    ]
    return {
        "source-tube-call": tube_call,
        "source-lane": source_lane,
        "typst-strand": strand,
        "typst-segment": segment,
        "typst-lane": typst_lane,
        "candidate-widths": candidate,
        "source-dash-leaves": len(source_intervals),
        "typst-dash-leaves": len(typst_intervals),
        "paired-leaf-count": len(paired),
        "mean-endpoint-arc-error-mm": (
            sum(endpoint_errors) / len(endpoint_errors) if endpoint_errors else None
        ),
        "max-endpoint-arc-error-mm": max(endpoint_errors) if endpoint_errors else None,
        "max-projection-error-mm": max(
            [leaf["projection-error-mm"] for leaf in source_intervals + typst_intervals]
        ),
        "source-intervals": source_intervals,
        "typst-intervals": typst_intervals,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_json", type=Path)
    parser.add_argument("--tube-call", type=int, default=2)
    parser.add_argument("--source-lane", type=int, default=6)
    parser.add_argument("--strand", type=int, default=0)
    parser.add_argument("--segment", type=int, default=0)
    parser.add_argument("--typst-lane", type=int, default=1)
    parser.add_argument("--candidate", action="store_true")
    args = parser.parse_args()
    print(json.dumps(compare(
        args.source_log, args.typst_json, args.tube_call, args.source_lane,
        args.strand, args.segment, args.typst_lane, args.candidate,
    ), indent=2))


if __name__ == "__main__":
    main()
