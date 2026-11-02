#!/usr/bin/env python3
"""Verify M11 width-template subpaths against 16.16 de Casteljau splits.

Usage: analyze_m11_q_splits.py MPOST_LOG [--call N] [--lane N]

The companion instrumenter emits M11QPT cubic controls and M11TCUTFIX
parameters as high/low base-256 digits. For each logged parent followed by its
recursive children, this checks that fixed-point de Casteljau subdivision
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


def mix_point(a, b, t):
    return [mix(a[0], b[0], t), mix(a[1], b[1], t)]


def split(segment, t):
    p0, p1, p2, p3 = segment
    a = mix_point(p0, p1, t)
    b = mix_point(p1, p2, t)
    c = mix_point(p2, p3, t)
    d = mix_point(a, b, t)
    e = mix_point(b, c, t)
    f = mix_point(d, e, t)
    return [p0, a, d, f], [f, e, c, p3]


def subpaths(segments, path_time):
    whole = path_time // SCALE
    fraction = path_time - whole * SCALE
    left = segments[:whole]
    right = []
    if fraction:
        if whole >= len(segments):
            raise ValueError(f"cut time {path_time / SCALE} exceeds q path")
        left_segment, right_segment = split(segments[whole], fraction)
        left.append(left_segment)
        right.append(right_segment)
        right.extend(segments[whole + 1 :])
    else:
        right.extend(segments[whole:])
    return left, right


def parse_groups(log, call, lane):
    groups = []
    current = None
    for line_number, line in enumerate(log.splitlines(), 1):
        fields = line.split()
        if not fields:
            continue
        if fields[0] == "M11QPT" and int(fields[1]) == call and int(fields[2]) == lane:
            depth, index, control = int(fields[3]), int(fields[4]), int(fields[5])
            if index == 0 and control == 0:
                current = {"line": line_number, "depth": depth, "segments": [], "cut": None}
                groups.append(current)
            if current is None or current["depth"] != depth:
                raise ValueError(f"orphan M11QPT at line {line_number}")
            if index == len(current["segments"]):
                current["segments"].append([])
            if index != len(current["segments"]) - 1 or control != len(current["segments"][index]):
                raise ValueError(f"out-of-order M11QPT at line {line_number}")
            values = fields[6:10]
            if len(values) != 4:
                raise ValueError(f"bad M11QPT field count at line {line_number}")
            current["segments"][index].append([
                decode_fixed(values[0], values[1]), decode_fixed(values[2], values[3])
            ])
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
    checked_left = 0
    checked_right = 0
    for index, parent in enumerate(groups[:-1]):
        child_depth = parent["depth"] + 1
        left_index = index + 1
        if parent["cut"] is None or left_index >= len(groups):
            continue
        left_child = groups[left_index]
        if left_child["depth"] != child_depth:
            continue
        expected_left, expected_right = subpaths(parent["segments"], parent["cut"])
        if expected_left != left_child["segments"]:
            raise SystemExit(
                f"left split mismatch: parent line {parent['line']} depth {parent['depth']} "
                f"cut {parent['cut'] / SCALE:.8f}, child line {left_child['line']}: "
                f"expected {len(expected_left)} segments, got {len(left_child['segments'])}"
            )
        checked_left += 1
        right_index = left_index + 1
        while right_index < len(groups) and groups[right_index]["depth"] > parent["depth"]:
            if groups[right_index]["depth"] == child_depth:
                break
            right_index += 1
        if right_index < len(groups) and groups[right_index]["depth"] == child_depth:
            right_child = groups[right_index]
            if expected_right != right_child["segments"]:
                raise SystemExit(
                    f"right split mismatch: parent line {parent['line']} depth {parent['depth']} "
                    f"cut {parent['cut'] / SCALE:.8f}, child line {right_child['line']}: "
                    f"expected {len(expected_right)} segments, got {len(right_child['segments'])}"
                )
            checked_right += 1
    if checked_left == 0:
        raise SystemExit("no parent/left-child q splits were checked")
    print(f"verified {checked_left} left-child and {checked_right} right-child "
          "two-dimensional q cubic splits exactly in 16.16 units")


if __name__ == "__main__":
    main()
