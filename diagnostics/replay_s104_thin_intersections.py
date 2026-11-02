#!/usr/bin/env python3
"""Replay Fiziko's midpoint selection from an instrumented S104 thin-brush log.

Usage: replay_s104_thin_intersections.py MPOST_LOG ROW [--node ID]

MetaPost's built-in ``intersectiontimes`` results are recorded as ``S104-FIRST``.
This script applies Fiziko's forward/reverse preference and cutPathTime's
midpoint-nearest choice to those raw results. It audits source decisions; it
does not approximate MetaPost's low-level intersectiontimes implementation.
"""

import argparse
from collections import defaultdict
from pathlib import Path


def load(log_path: str, row: float):
    nodes = defaultdict(lambda: {
        "first": [], "controls": defaultdict(dict), "thin": None,
        "hit": None, "hit_x": None,
    })
    for line in Path(log_path).read_text().splitlines():
        p = line.split()
        if len(p) < 3 or p[0] not in {
            "S104-FIRST", "S104-TXCTRL", "S104-THIN",
            "S104-THIN-HIT-T", "S104-THIN-HIT-X",
        }:
            continue
        if abs(float(p[1]) - row) > 0.00001:
            continue
        node = nodes[int(p[2])]
        if p[0] == "S104-FIRST":
            node["first"].append(tuple(map(float, p[3:7])))
        elif p[0] == "S104-TXCTRL":
            segment, control = int(p[4]), int(p[5])
            node["controls"][segment][control] = (int(p[6]) + int(p[7]) / 256) / 256
        elif p[0] == "S104-THIN":
            node["thin"] = {
                "depth": int(p[3]), "time": float(p[9]),
                "length": float(p[10]),
            }
        elif p[0] == "S104-THIN-HIT-T":
            node["hit"] = tuple(map(float, p[3:7]))
        elif p[0] == "S104-THIN-HIT-X":
            node["hit_x"] = tuple(map(float, p[3:5]))
    return nodes


def source_first_intersection(raw, path_length):
    """Apply the pinned firstIntersectionTimes macro to its raw pair."""
    x1, y1, x2, y2 = raw
    if x1 < x2:
        return x1, y1
    result = x2, path_length - y2
    if x1 < 0:
        return x2, y2
    return result


def replay(node):
    first, second = node["first"][-2:]
    path_length = len(node["controls"])
    cut1 = source_first_intersection(first, path_length)
    cut2 = source_first_intersection(second, path_length)
    _, d3, source_cut1, source_cut2 = node["hit"]
    d4, d5 = node["hit_x"]
    chosen = cut1[1] if abs(d4 - d3) < abs(d5 - d3) else cut2[1]
    return {
        "cut1": cut1[1], "cut2": cut2[1], "chosen": chosen,
        "source_cut1": source_cut1, "source_cut2": source_cut2,
        "source_cut": node["thin"]["time"], "d3": d3, "d4": d4,
        "d5": d5,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("row", type=float)
    parser.add_argument("--node", type=int)
    args = parser.parse_args()

    nodes = load(args.log, args.row)
    if args.node is not None:
        nodes = {args.node: nodes[args.node]} if args.node in nodes else {}
    replayed = []
    for serial, node in sorted(nodes.items()):
        if node["thin"] is None:
            continue
        if node["hit"] is None or node["hit_x"] is None or len(node["first"]) < 2:
            continue
        result = replay(node)
        result["serial"] = serial
        result["raw_match"] = max(
            abs(result["cut1"] - result["source_cut1"]),
            abs(result["cut2"] - result["source_cut2"]),
        ) <= 0.00002
        result["cut_match"] = abs(result["chosen"] - result["source_cut"]) <= 0.00002
        replayed.append(result)

    if not replayed:
        raise SystemExit("no complete S104 thin-intersection records for this row")
    print(f"row {args.row:g}: replayed {len(replayed)} source cut decisions")
    print("raw firstIntersectionTimes pairs reproduce cutPathTime:",
          f"{sum(item['raw_match'] for item in replayed)}/{len(replayed)}")
    print("midpoint-nearest selection reproduces source cut:",
          f"{sum(item['cut_match'] for item in replayed)}/{len(replayed)}")
    print("node source-cut1 replay-cut1 source-cut2 replay-cut2 chosen source-cut d3 d4 d5")
    for item in replayed:
        print(f"{item['serial']:4d} {item['source_cut1']:10.6f} "
              f"{item['cut1']:10.6f} {item['source_cut2']:10.6f} "
              f"{item['cut2']:10.6f} {item['chosen']:10.6f} "
              f"{item['source_cut']:10.6f} {item['d3']:10.5f} "
              f"{item['d4']:10.5f} {item['d5']:10.5f}")


if __name__ == "__main__":
    main()
