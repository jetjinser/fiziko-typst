#!/usr/bin/env python3
"""Audit the fixed-point controls and times recorded by the S104 tracer.

Usage: audit_s104_fixed_encoding.py MPOST_LOG ROW
"""

import argparse
from collections import defaultdict
from pathlib import Path


def packed(high: str, low: str) -> float:
    """Decode the tracer's base-256 pair as a signed 16.16 value."""
    return (int(high) * 256 + int(low)) / 65536


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("row", type=float)
    args = parser.parse_args()

    controls = {}
    x_controls = {}
    rays = defaultdict(dict)
    entries = {}
    hit_values = {}
    decimal_hits = defaultdict(list)
    fixed_hits = defaultdict(list)
    carry_chunks = 0
    for line in Path(args.log).read_text().splitlines():
        fields = line.split()
        if (not fields or fields[0] not in {
                "S104-TCTRL", "S104-TXCTRL", "S104-TRAY", "S104-TENTRY",
                "S104-THIN-HIT-T", "S104-FIRST", "S104-FIRST-FIX"}):
            continue
        if abs(float(fields[1]) - args.row) > 0.00001:
            continue
        tag = fields[0]
        node = int(fields[2])
        if tag == "S104-TCTRL":
            key = (node, int(fields[3]), int(fields[4]), int(fields[5]))
            controls[key] = (
                float(fields[6]), float(fields[7]), packed(fields[8], fields[9]))
        elif tag == "S104-TXCTRL":
            key = (node, int(fields[3]), int(fields[4]), int(fields[5]))
            x_controls[key] = (packed(fields[6], fields[7]), None)
        elif tag == "S104-TRAY":
            ray, control = int(fields[3]), int(fields[4])
            rays[node].setdefault(ray, {})[control] = (
                packed(fields[5], fields[6]), packed(fields[7], fields[8]))
        elif tag == "S104-TENTRY":
            entries[node] = tuple(map(float, fields[4:7]))
        elif tag == "S104-THIN-HIT-T":
            hit_values[node] = tuple(map(float, fields[3:]))
        elif tag == "S104-FIRST":
            decimal_hits[node].append(tuple(map(float, fields[3:7])))
        elif tag == "S104-FIRST-FIX":
            chunks = fields[3:11]
            carry_chunks += sum(int(chunks[index]) == 256
                                for index in (1, 3, 5, 7))
            fixed_hits[node].append(tuple(
                packed(chunks[index], chunks[index + 1])
                for index in (0, 2, 4, 6)
            ))

    x_errors = []
    y_errors = []
    for key, (x_decimal, y_decimal, y_fixed) in controls.items():
        x_errors.append(abs(x_controls[key][0] - x_decimal))
        y_errors.append(abs(y_decimal - y_fixed))

    ray_errors = []
    ray_pairs = 0
    for node, node_rays in rays.items():
        if node not in entries or node not in hit_values:
            continue
        d1, d2, _ = entries[node]
        h, d3 = hit_values[node][:2]
        for ray_id, endpoint in ((1, d1), (2, d2)):
            for control, expected_x in ((0, d3), (3, endpoint)):
                actual_x, actual_y = node_rays[ray_id][control]
                ray_errors.extend((abs(actual_x - expected_x), abs(actual_y - h)))
                ray_pairs += 1

    hit_errors = []
    hit_pairs = 0
    for node, decimal_values in decimal_hits.items():
        for decimal_pair, fixed_pair in zip(decimal_values, fixed_hits[node]):
            hit_errors.extend(abs(a - b) for a, b in zip(decimal_pair, fixed_pair))
            hit_pairs += 1
    print(f"cubic controls: {len(controls)}; x/y max decode error vs decimal: "
          f"{max(x_errors):.9g}/{max(y_errors):.9g}")
    print(f"ray endpoints: {ray_pairs}; max decode error vs cut decimals: "
          f"{max(ray_errors):.9g}")
    print(f"raw hit pairs: {hit_pairs}; max fixed-vs-decimal difference: "
          f"{max(hit_errors):.9g}; low-byte 256 carries: {carry_chunks}")


if __name__ == "__main__":
    main()
