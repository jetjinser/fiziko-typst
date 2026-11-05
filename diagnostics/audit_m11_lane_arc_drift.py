#!/usr/bin/env python3
"""Report local and cumulative M11 lane q-arc errors against source."""

import argparse
import json
from collections import defaultdict
from pathlib import Path


def source_arcs(path):
    records = defaultdict(dict)
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) == 7 and fields[0] == "M11POSTARC":
            call, lane, segment = map(int, fields[1:4])
            records[call, lane][segment + 1] = (
                int(fields[4]) * 65536 + int(fields[5]) * 256
                + int(fields[6])
            )
    for key, points in records.items():
        if sorted(points) != list(range(1, len(points) + 1)):
            raise ValueError(f"non-contiguous source arc knots for {key}")
    return records


def audit(log, replay, arc_field, polyline_steps):
    source = source_arcs(log)
    for item in replay:
        key = item["call"], item["lane"]
        if key not in source:
            continue
        expected = [0] + [source[key][i] for i in range(1, len(source[key]) + 1)]
        traced = item["source-arc-fixed"]
        actual = item[arc_field]
        if arc_field == "polyline-arc-fixed":
            table = next(record for record in item["polyline-arc-runs"]
                         if record["steps"] == polyline_steps)
            actual = table["arcs"]
        if traced != expected:
            raise ValueError(f"replay source arc table differs from source for {key}")
        if len(actual) != len(expected):
            raise ValueError(f"arc knot count differs for {key}: {len(actual)} vs {len(expected)}")

        drift = [got - ref for got, ref in zip(actual, expected)]
        increment_errors = [drift[i + 1] - drift[i]
                            for i in range(len(drift) - 1)]
        largest = sorted(enumerate(increment_errors),
                         key=lambda pair: abs(pair[1]), reverse=True)[:5]
        print(f"call={key[0]} lane={key[1]} segments={len(increment_errors)} "
              f"endpoint-drift={drift[-1]} "
              f"local-error-range={min(increment_errors)}/{max(increment_errors)} "
              f"max-abs={max(map(abs, increment_errors))}")
        print("  largest segment errors (zero-based segment, fixed units): "
              + ", ".join(f"{i}:{value:+d}" for i, value in largest))
        node_index = {(4, 2): 32, (4, 6): 10, (5, 2): 19}.get(key)
        if node_index is not None:
            if arc_field == "polyline-arc-fixed":
                run = next(record for record in item["polyline-arc-runs"]
                           if record["steps"] == polyline_steps)
                all_nodes = run["q-nodes"]
            else:
                field = {"arc-fixed": "q-nodes",
                         "fifth-arc-fixed": "fifth-arc-q-nodes"}[arc_field]
                all_nodes = item[field]
            nodes = [node for node in all_nodes if node["stage"] == "thin"]
            node = nodes[node_index]
            print(f"  first divergent thin node {node_index + 1}: "
                  f"depth={node['depth']} q-map={node['q-map']}")
            spans = node["q-map"]
            first_segment = max(0, int(min(span[0] for span in spans)))
            last_segment = min(len(increment_errors),
                               int(max(span[1] for span in spans)) + 1)
            local = [(i, increment_errors[i])
                     for i in range(first_segment, last_segment)]
            print("  q-map segment errors (zero-based segment, fixed units): "
                  + ", ".join(f"{i}:{value:+d}" for i, value in local))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("replay_json", type=Path)
    parser.add_argument("--arc-field", default="arc-fixed",
                        choices=("arc-fixed", "fifth-arc-fixed",
                                 "polyline-arc-fixed"))
    parser.add_argument("--polyline-steps", type=int, default=16,
                        choices=(1, 2, 4, 8, 16, 32, 64))
    args = parser.parse_args()
    audit(args.source_log, json.loads(args.replay_json.read_text()),
          args.arc_field, args.polyline_steps)


if __name__ == "__main__":
    main()
