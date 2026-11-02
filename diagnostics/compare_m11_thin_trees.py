#!/usr/bin/env python3
"""Compare traced MetaPost and Typst M11 thin-recursion trees.

Usage: compare_m11_thin_trees.py MPOST_LOG REPLAY_JSON
"""

import argparse
import json
from pathlib import Path


def source_nodes(log, call, lane):
    records = []
    lines = log.splitlines()
    for index, line in enumerate(lines):
        fields = line.split()
        if len(fields) != 7 or fields[0] != "M11THIN":
            continue
        if (int(fields[1]), int(fields[2])) != (call, lane):
            continue
        node = {
            "depth": int(fields[3]),
            "width-start": float(fields[4]),
            "width-end": float(fields[5]),
            "length": float(fields[6]),
            "cut": None,
        }
        for next_line in lines[index + 1 :]:
            next_fields = next_line.split()
            if next_fields[:3] == ["M11THIN", str(call), str(lane)]:
                break
            if (len(next_fields) == 6 and next_fields[0] == "M11TCUT"
                    and (int(next_fields[1]), int(next_fields[2])) == (call, lane)):
                node["cut"] = float(next_fields[5])
        records.append(node)
    for index, node in enumerate(records):
        node["recurse"] = (
            index + 1 < len(records)
            and records[index + 1]["depth"] > node["depth"]
        )
    return records


def source_q_paths(log, call, lane):
    paths = []
    current = None
    for line in log.splitlines():
        fields = line.split()
        if not fields or fields[0] != "M11QPT":
            continue
        if (int(fields[1]), int(fields[2])) != (call, lane):
            continue
        _, segment, control = map(int, fields[3:6])
        if segment == 0 and control == 0:
            current = []
            paths.append(current)
        if current is None:
            raise ValueError("M11QPT control appeared before its first segment")
        if control == 0:
            current.append([])
        current[segment].append([
            int(fields[6]) * 256 + int(fields[7]),
            int(fields[8]) * 256 + int(fields[9]),
        ])
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("replay_json")
    parser.add_argument("--nodes-field", default="q-nodes",
                        choices=("q-nodes", "fifth-arc-q-nodes", "blended-arc-q-nodes",
                                 "source-arc-q-nodes"))
    args = parser.parse_args()
    log = Path(args.log).read_text()
    replay = json.loads(Path(args.replay_json).read_text())
    for call, lane in ((4, 2), (4, 6), (5, 2)):
        source = source_nodes(log, call, lane)
        source_q = source_q_paths(log, call, lane)
        item = next(record for record in replay
                    if (record["call"], record["lane"]) == (call, lane))
        candidate = [node for node in item[args.nodes_field]
                     if node["stage"] == "thin"]
        if len(source) != len(source_q):
            raise ValueError(
                f"call {call}/lane {lane}: {len(source)} source nodes but "
                f"{len(source_q)} source q paths"
            )
        first = next((index for index, (left, right) in enumerate(
            zip(source, candidate))
            if left["depth"] != right["depth"]
            or left["recurse"] != right["recurse"]), None)
        exact_q_count = sum(
            source_q[index] == node.get("q-curves-fixed")
            for index, node in enumerate(candidate[:len(source_q)])
        )
        if first is None and len(source) == len(candidate):
            print(f"call={call} lane={lane}: exact tree ({len(source)} nodes), "
                  f"exact q controls={exact_q_count}/{len(source_q)}")
            continue
        print(f"call={call} lane={lane}: source={len(source)} candidate={len(candidate)} "
              f"first-decision-difference={first}")
        if first is not None:
            left, right = source[first], candidate[first]
            exact_q = (first < len(source_q) and first < len(candidate)
                       and source_q[first] == right.get("q-curves-fixed"))
            print("  source: "
                  f"depth={left['depth']} width={left['width-start']:.8f}/"
                  f"{left['width-end']:.8f} length={left['length']:.5f} "
                  f"cut={left['cut']} recurse={left['recurse']}")
            print("  replay: "
                  f"depth={right['depth']} width={right['width-min']:.8f}/"
                  f"{right['width-max']:.8f} target={right['target']:.8f} "
                  f"length={right['length']:.5f} cut={right['cut-param']} "
                  f"children={right['left-length']:.5f}/"
                  f"{right['right-length']:.5f} recurse={right['recurse']} "
                  f"q-controls-exact={exact_q} "
                  f"overall-exact-q-controls={exact_q_count}/{len(source_q)}")


if __name__ == "__main__":
    main()
