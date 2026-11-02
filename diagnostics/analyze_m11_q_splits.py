#!/usr/bin/env python3
"""Verify M11 width-template left subpaths against 16.16 de Casteljau splits.

Usage: analyze_m11_q_splits.py MPOST_LOG [--call N] [--lane N]

The companion instrumenter emits M11QSEG cubic controls and M11TCUTFIX
parameters as high/low base-256 digits. For each logged parent followed by its
left recursive child, this checks that fixed-point de Casteljau subdivision
reproduces every child's q-path control point.
"""

import argparse
from pathlib import Path


SCALE = 1 << 16


def decode_fixed(high, low):
    return int(high) * 256 + int(low)


def round_div_nearest(value, divisor):
    if value < 0:
        return -round_div_nearest(-value, divisor)
    return (value + divisor // 2) // divisor


def mix(a, b, t):
    return a + round_div_nearest((b - a) * t, SCALE)


def split_left(segment, t):
    p0, p1, p2, p3 = segment
    a = mix(p0, p1, t)
    b = mix(p1, p2, t)
    c = mix(p2, p3, t)
    d = mix(a, b, t)
    e = mix(b, c, t)
    f = mix(d, e, t)
    return [p0, a, d, f]


def left_subpath(segments, path_time):
    whole = path_time // SCALE
    fraction = path_time - whole * SCALE
    result = segments[:whole]
    if fraction:
        if whole >= len(segments):
            raise ValueError(f"cut time {path_time / SCALE} exceeds q path")
        result.append(split_left(segments[whole], fraction))
    return result


def parse_groups(log, call, lane):
    groups = []
    current = None
    for line_number, line in enumerate(log.splitlines(), 1):
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "M11QSEG" and int(fields[1]) == call and int(fields[2]) == lane:
            depth, index = int(fields[3]), int(fields[4])
            if index == 0:
                current = {"line": line_number, "depth": depth, "segments": [], "cut": None}
                groups.append(current)
            if current is None or current["depth"] != depth:
                raise ValueError(f"orphan M11QSEG at line {line_number}")
            values = fields[5:13]
            if len(values) != 8:
                raise ValueError(f"bad M11QSEG field count at line {line_number}")
            raw = [decode_fixed(values[i], values[i + 1]) for i in range(0, 8, 2)]
            current["segments"].append(raw)
        elif fields[0] == "M11TCUTFIX" and int(fields[1]) == call and int(fields[2]) == lane:
            if current is None:
                raise ValueError(f"orphan M11TCUTFIX at line {line_number}")
            current["cut"] = decode_fixed(fields[4], fields[5])
    return groups


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("--call", type=int, default=4)
    parser.add_argument("--lane", type=int, default=2)
    args = parser.parse_args()
    groups = parse_groups(Path(args.log).read_text(), args.call, args.lane)
    checked = 0
    for index, parent in enumerate(groups[:-1]):
        child = groups[index + 1]
        if parent["cut"] is None or child["depth"] != parent["depth"] + 1:
            continue
        expected = left_subpath(parent["segments"], parent["cut"])
        if expected != child["segments"]:
            raise SystemExit(
                f"left split mismatch: parent line {parent['line']} depth {parent['depth']} "
                f"cut {parent['cut'] / SCALE:.8f}, child line {child['line']}: "
                f"expected {len(expected)} segments, got {len(child['segments'])}"
            )
        checked += 1
    if checked == 0:
        raise SystemExit("no parent/left-child q splits were checked")
    print(f"verified {checked} left-child q cubic splits exactly in 16.16 units")


if __name__ == "__main__":
    main()
