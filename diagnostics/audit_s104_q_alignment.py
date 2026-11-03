#!/usr/bin/env python3
"""Compare source and Typst S104 recursive q curves by paired row/node geometry."""

import argparse
import json
from collections import defaultdict
from pathlib import Path

from compare_s104_row_calls import source_rows


def source_q_records(trace: Path, y_sum: float):
    endpoints = defaultdict(dict)
    controls = defaultdict(dict)
    for line in trace.read_text().splitlines():
        fields = line.split()
        if not fields:
            continue
        tag = fields[0]
        if tag == "S104-TNODE":
            row, serial = float(fields[1]), int(fields[2])
            endpoints[row][serial] = (
                float(fields[4]), y_sum - float(fields[5]),
                float(fields[6]), y_sum - float(fields[7]),
            )
        elif tag in ("S104-TXCTRL", "S104-TCTRL"):
            row, serial = float(fields[1]), int(fields[2])
            curve, control = int(fields[4]), int(fields[5])
            axis = 0 if tag == "S104-TXCTRL" else 1
            if axis == 0:
                value = int(fields[6]) * 256 + int(fields[7])
            else:
                value = int(fields[8]) * 256 + int(fields[9])
            controls[row, serial][curve, control, axis] = value
    return endpoints, controls


def node_distance(source, node):
    start, end = node["path-start"], node["path-end"]
    direct = sum((a - b) ** 2 for a, b in zip(
        source, (*start, *end))) ** 0.5
    reverse = sum((a - b) ** 2 for a, b in zip(
        source, (*end, *start))) ** 0.5
    return min(direct, reverse), reverse < direct


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_log", type=Path)
    parser.add_argument("typst_trace", type=Path)
    parser.add_argument("--y-sum", type=float, default=44.0,
                        help="source/Typst vertical flip is y_typst = y-sum - y_source")
    parser.add_argument("--endpoint-tolerance", type=float, default=0.005,
                        help="maximum summed endpoint distance in mm")
    parser.add_argument("--source-y", type=float,
                        help="restrict the audit to one source row coordinate")
    args = parser.parse_args()

    src_rows = source_rows(args.source_log)
    typ_doc = json.loads(args.typst_trace.read_text())
    typ_rows = typ_doc["rows"]
    if len(src_rows) != len(typ_rows):
        raise ValueError(f"row counts differ: source {len(src_rows)}, Typst {len(typ_rows)}")

    endpoints, controls = source_q_records(args.source_log, args.y_sum)
    totals = defaultdict(int)
    row_reports = []
    x_errors = []
    considered_rows = 0
    for row_index, (src_row, typ_row) in enumerate(zip(src_rows, typ_rows), 1):
        source_y = src_row["row"]
        if args.source_y is not None and abs(source_y - args.source_y) > 1e-5:
            continue
        considered_rows += 1
        candidates = [node for node in typ_row.get("fixed-width-q-nodes", ())
                      if node["stage"] == "thin" and node.get("q-curves-fixed")]
        used = set()
        row_matched = 0
        for serial, source_ends in endpoints.get(source_y, {}).items():
            totals["source-nodes"] += 1
            nearest = None
            for index, node in enumerate(candidates):
                if index in used:
                    continue
                distance, reverse = node_distance(source_ends, node)
                if nearest is None or distance < nearest[0]:
                    nearest = (distance, index, node, reverse)
            if nearest is None or nearest[0] > args.endpoint_tolerance:
                continue
            distance, index, node, reverse = nearest
            used.add(index)
            row_matched += 1
            totals["endpoint-pairs"] += 1
            totals["reverse-pairs"] += reverse
            source_controls = controls.get((source_y, serial), {})
            source_curve_count = 1 + max(
                (key[0] for key in source_controls), default=-1)
            typ_curves = node["q-curves-fixed"]
            if reverse or source_curve_count != len(typ_curves):
                continue
            if any((curve, point, axis) not in source_controls
                   for curve in range(source_curve_count)
                   for point in range(4) for axis in range(2)):
                continue
            deltas = [
                source_controls[curve, point, axis]
                - typ_curves[curve][point][axis]
                for curve in range(source_curve_count)
                for point in range(4) for axis in range(2)
            ]
            totals["q-control-pairs"] += 1
            if all(delta == 0 for delta in deltas[1::2]):
                totals["exact-width-controls"] += 1
            if all(delta == 0 for delta in deltas[0::2]):
                totals["exact-arc-controls"] += 1
            x_errors.extend(abs(delta) for delta in deltas[0::2])
        row_reports.append((row_index, source_y, typ_row.get("row"),
                            len(endpoints.get(source_y, {})), row_matched))

    print(f"paired rows: {considered_rows}; source nodes: {totals['source-nodes']}; "
          f"endpoint pairs: {totals['endpoint-pairs']}; "
          f"q-control pairs: {totals['q-control-pairs']}")
    print(f"exact width-control nodes: {totals['exact-width-controls']}; "
          f"exact arc-control nodes: {totals['exact-arc-controls']}; "
          f"reversed endpoint pairs: {totals['reverse-pairs']}")
    if x_errors:
        print(f"absolute q-arc control error in 16.16 bp units: "
              f"mean={sum(x_errors) / len(x_errors):.3f}, "
              f"max={max(x_errors)}")
    print("rows with unmatched source nodes:")
    for index, source_y, typ_row, source_count, matched in row_reports:
        if source_count > matched:
            print(f"  pair {index}: source y={source_y:.5f}, Typst row={typ_row}, "
                  f"nodes={matched}/{source_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
